//
//  CloudMapViewModel.swift
//  PhotoPlanner
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation


@Observable
class CloudMapViewModel {

    // Radar
    var radarFrames           : [CloudMapFrame] = []
    var radarLoading          : Bool            = false
    var radarFailed           : Bool            = false
    var radarCurrentIndex     : Int             = 0
    var radarPlaying          : Bool            = true

    // Satellite
    var satelliteFrames       : [CloudMapFrame] = []
    var satelliteLoading      : Bool            = false
    var satelliteFailed       : Bool            = false
    var satelliteCurrentIndex : Int             = 0
    var satellitePlaying      : Bool            = true

    // Wind
    var windSamples           : [WindSample]    = []
    var windLoading           : Bool            = false
    var windVisible           : Bool            = false   // toggled by wind button

    private let zoomLevel     : Int             = 7
    private let libreWxrHost  : String          = "http://hansolo.eu:8081"
    private let manifestURL   : String          = "http://hansolo.eu:8081/public/weather-maps.json"
    private let windFetcher   : WindFetcher     = WindFetcher()
    
    private var regionSpanLat : Double                 = 0
    private var regionSpanLon : Double                 = 0
    private var regionCenter  : CLLocationCoordinate2D = CLLocationCoordinate2D()


    func loadAll(coordinate: CLLocationCoordinate2D, scale: CGFloat) async {
        async let radarTask     : Void = loadRadarFrames(coordinate: coordinate, scale: scale)
        async let satelliteTask : Void = loadSatelliteFrames(coordinate: coordinate, scale: scale)
        _ = await (radarTask, satelliteTask)
        // Wind loads separately — only when toggled on
    }


    func loadWind(coordinate: CLLocationCoordinate2D) async {
        guard !windLoading else { return }
        windLoading = true
        windSamples = []

        windSamples = await windFetcher.fetchGrid(
            center:  coordinate,
            spanLat: regionSpanLat > 0 ? regionSpanLat : 2.25,   // ~250km fallback
            spanLon: regionSpanLon > 0 ? regionSpanLon : 3.50
        )
        windLoading = false
    }

    // Returns the current frame's image composited with wind arrows if enabled.
    func currentImage(for mode: CloudMapMode) -> UIImage? {
        let frames : [CloudMapFrame] = mode == .radar ? radarFrames       : satelliteFrames
        let index  : Int             = mode == .radar ? radarCurrentIndex : satelliteCurrentIndex
        guard !frames.isEmpty, index < frames.count else { return nil }

        let frame : CloudMapFrame = frames[index]

        guard windVisible && !windSamples.isEmpty else { return frame.image }

        // Draw wind arrows onto the frame image
        let frameDate : Date = Date(timeIntervalSince1970: TimeInterval(frame.time))
        
        debugPrint("[Wind] drawing with regionSpanLat: \(regionSpanLat) regionSpanLon: \(regionSpanLon) centerLat: \(regionCenter.latitude) centerLon: \(regionCenter.longitude)")
        return WindArrowRenderer.draw(onto: frame.image, samples: windSamples, at: frameDate, regionLat: regionSpanLat, regionLon: regionSpanLon, centerLat: regionCenter.latitude, centerLon: regionCenter.longitude)
    }


    func loadRadarFrames(coordinate: CLLocationCoordinate2D, scale: CGFloat) async {
        radarLoading      = true
        radarFailed       = false
        radarFrames       = []
        radarCurrentIndex = 0
        
        let tileSize : Int = Properties.instance.hiResWeatherMap! ? 512 : 256

        let colorScheme = Properties.instance.libreWxrColorScheme ?? 8

        guard let manifest = await fetchManifest(),
              let base     = await fetchBaseMap(coordinate: coordinate, scale: scale)
        else {
            radarLoading = false
            radarFailed  = true
            return
        }

        let tile    = MapTile.tile(for: coordinate, zoom: zoomLevel)
        let past    = manifest.radar.past.map    { ($0.time, $0.path, false) }
        let nowcast = manifest.radar.nowcast.map { ($0.time, $0.path, true)  }

        let frames: [CloudMapFrame] = await withTaskGroup(of: CloudMapFrame?.self) { group in
            for (time, path, isNowcast) in past + nowcast {
                group.addTask { [weak self] in
                    guard let self,
                          let url     = tile.libreWxrURL(host: manifest.host, path: path, colorScheme: colorScheme, tileSize: tileSize),
                          let tileImg = await self.fetchTileImage(from: url)
                    else { return nil }
                    let composited = await self.composite(base: base, overlay: tileImg, tileIndex: tile, region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: regionCenter.latitude, longitude: regionCenter.longitude), span: MKCoordinateSpan(latitudeDelta: regionSpanLat, longitudeDelta: regionSpanLon)), alpha: 0.85)
                    
                    return CloudMapFrame(time: time, image: composited, isNowcast: isNowcast)
                }
            }
            var results: [CloudMapFrame] = []
            for await frame in group { if let frame { results.append(frame) } }
            return results.sorted { $0.time < $1.time }
        }

        radarFrames  = frames
        radarLoading = false
        radarFailed  = frames.isEmpty

        if let lastPast = frames.lastIndex(where: { !$0.isNowcast }) {
            radarCurrentIndex = lastPast
        }
    }

    func advanceRadarFrame() {
        guard !radarFrames.isEmpty else { return }
        radarCurrentIndex = (radarCurrentIndex + 1) % radarFrames.count
    }

    func frameTimeLabel(for frame: CloudMapFrame) -> String {
        let date      = Date(timeIntervalSince1970: TimeInterval(frame.time))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr   = formatter.string(from: date)
        return frame.isNowcast ? "\(timeStr) ▶ forecast" : timeStr
    }

    func loadSatelliteFrames(coordinate: CLLocationCoordinate2D, scale: CGFloat) async {
        satelliteLoading      = true
        satelliteFailed       = false
        satelliteFrames       = []
        satelliteCurrentIndex = 0
        
        guard let manifest  = await fetchManifest(),
              let satellite = manifest.satellite,
              !satellite.infrared.isEmpty,
              let base      = await fetchBaseMap(coordinate: coordinate, scale: scale)
        else {
            satelliteLoading = false
            satelliteFailed  = true
            return
        }

        let tile = MapTile.tile(for: coordinate, zoom: zoomLevel)

        let frames: [CloudMapFrame] = await withTaskGroup(of: CloudMapFrame?.self) { group in
            for frame in satellite.infrared {
                group.addTask { [weak self] in
                    guard let self,
                          let url     = tile.libreWxrSatelliteURL(host: manifest.host, path: frame.path),
                          let tileImg = await self.fetchTileImage(from: url)
                    else { return nil }
                    let composited = await self.composite(base: base, overlay: tileImg, tileIndex: tile, region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: regionCenter.latitude, longitude: regionCenter.longitude), span: MKCoordinateSpan(latitudeDelta: regionSpanLat, longitudeDelta: regionSpanLon)), alpha: 0.9)
                    return CloudMapFrame(time: frame.time, image: composited, isNowcast: false)
                }
            }
            var results: [CloudMapFrame] = []
            for await frame in group { if let frame { results.append(frame) } }
            return results.sorted { $0.time < $1.time }
        }

        satelliteFrames  = frames
        satelliteLoading = false
        satelliteFailed  = frames.isEmpty

        if !frames.isEmpty { satelliteCurrentIndex = frames.count - 1 }
    }

    func advanceSatelliteFrame() {
        guard !satelliteFrames.isEmpty else { return }
        satelliteCurrentIndex = (satelliteCurrentIndex + 1) % satelliteFrames.count
    }


    private func fetchManifest() async -> LibreWxrResponse? {
        guard let url = URL(string: manifestURL) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let response   = try? JSONDecoder().decode(LibreWxrResponse.self, from: data)
        else { return nil }
        return response
    }

    private func fetchBaseMap(coordinate: CLLocationCoordinate2D, scale: CGFloat) async -> UIImage? {
        let region   : MKCoordinateRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: 250_000, longitudinalMeters: 250_000)
        let tileSize : CGFloat            = Properties.instance.hiResWeatherMap! ? 512 : 360
        
        // Store region span for wind grid and arrow positioning
        regionCenter  = coordinate
        regionSpanLat = region.span.latitudeDelta
        regionSpanLon = region.span.longitudeDelta

        let options            = MKMapSnapshotter.Options()
        options.region         = region
        options.size           = CGSize(width: tileSize, height: tileSize)
        options.scale          = scale
        options.mapType        = .standard
        options.showsBuildings = false
        return try? await MKMapSnapshotter(options: options).start().image.tonal
    }

    nonisolated private func fetchTileImage(from url: URL) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        return UIImage(data: data)
    }

    nonisolated private func composite(base: UIImage, overlay: UIImage?, tileIndex: MapTile?, region: MKCoordinateRegion?, alpha: CGFloat) -> UIImage {
        let size     : CGSize                  = base.size
        let renderer : UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))

            if let overlay {
                if let tile = tileIndex, let reg = region {
                    // Position tile using Mercator projection — correct for latitude distortion
                    func mercY(_ lat: Double) -> Double {
                        let rad : Double = lat * .pi / 180.0
                        return log(tan(.pi / 4.0 + rad / 2.0))
                    }

                    let n         : Double = pow(2.0, Double(tile.z))
                    let tileNorth : Double = atan(sinh(.pi * (1.0 - 2.0 * Double(tile.y)     / n))) * 180.0 / .pi
                    let tileSouth : Double = atan(sinh(.pi * (1.0 - 2.0 * Double(tile.y + 1) / n))) * 180.0 / .pi
                    let tileWest  : Double = Double(tile.x)     / n * 360.0 - 180.0
                    let tileEast  : Double = Double(tile.x + 1) / n * 360.0 - 180.0

                    let regNorth : CGFloat = reg.center.latitude  + reg.span.latitudeDelta  / 2
                    let regSouth : CGFloat = reg.center.latitude  - reg.span.latitudeDelta  / 2
                    let regWest  : CGFloat = reg.center.longitude - reg.span.longitudeDelta / 2
                    let regEast  : CGFloat = reg.center.longitude + reg.span.longitudeDelta / 2

                    let mercRegNorth  : CGFloat = mercY(regNorth)
                    let mercRegSouth  : CGFloat = mercY(regSouth)
                    let mercTileNorth : CGFloat = mercY(tileNorth)
                    let mercTileSouth : CGFloat = mercY(tileSouth)
                    let mercRegHeight : CGFloat = mercRegNorth - mercRegSouth

                    let x : CGFloat = CGFloat((tileWest  - regWest)  / (regEast - regWest))  * size.width
                    let w : CGFloat = CGFloat((tileEast  - tileWest) / (regEast - regWest))  * size.width
                    let y : CGFloat = CGFloat((mercRegNorth - mercTileNorth) / mercRegHeight) * size.height
                    let h : CGFloat = CGFloat((mercTileNorth - mercTileSouth) / mercRegHeight) * size.height

                    overlay.draw(in: CGRect(x: x, y: y, width: w, height: h), blendMode: .normal, alpha: alpha)
                } else {
                    overlay.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: alpha)
                }
            }

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.3).cgColor] as CFArray, locations: [0.7, 1.0])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: size.width * 0.35, endCenter: CGPoint(x: size.width / 2, y: size.height / 2), endRadius: size.width * 0.72, options: [])
        }
    }
}
