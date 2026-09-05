//
//  CloudMapViewModel.swift
//  PhotoPlanner
//

import Foundation
import CoreLocation
import MapKit
import UIKit

@Observable
class CloudMapViewModel {

    // Radar
    var radarFrames             : [CloudMapFrame] = []
    var radarLoading            : Bool            = false
    var radarFailed             : Bool            = false
    var radarCurrentIndex       : Int             = 0
    var radarPlaying            : Bool            = true

    // Satellite
    var satelliteFrames         : [CloudMapFrame] = []
    var satelliteLoading        : Bool            = false
    var satelliteFailed         : Bool            = false
    var satelliteCurrentIndex   : Int             = 0
    var satellitePlaying        : Bool            = true

    // Wind
    var windSamples             : [WindSample]    = []
    var windLoading             : Bool            = false
    var windVisible             : Bool            = false   // toggled by wind button

    private let zoomLevel       : Int             = 7
    private let libreWxrHost    : String          = "http://hansolo.eu:8081"
    private let manifestURL     : String          = "http://hansolo.eu:8081/public/weather-maps.json"
    private let windFetcher     : WindFetcher     = WindFetcher()
    
    private var radarRegion     : MKCoordinateRegion?
    private var satelliteRegion : MKCoordinateRegion?


    func loadAll(coordinate: CLLocationCoordinate2D, scale: CGFloat) async {
        async let radarTask     : Void = loadRadarFrames(coordinate: coordinate, scale: scale)
        async let satelliteTask : Void = loadSatelliteFrames(coordinate: coordinate, scale: scale)
        _ = await (radarTask, satelliteTask)
    }


    func loadWind(coordinate: CLLocationCoordinate2D) async {
        guard !windLoading else { return }
        windLoading = true
        windSamples = []

        let region = radarRegion ?? satelliteRegion

        windSamples = await windFetcher.fetchGrid(center: coordinate, spanLat: region?.span.latitudeDelta ?? 2.25, spanLon: region?.span.longitudeDelta ?? 3.50) // ~250km fallback
        windLoading = false
    }

    // Returns the current frame's image composited with wind arrows if enabled.
    func currentImage(for mode: CloudMapMode) -> UIImage? {
        let frames : [CloudMapFrame] = mode == .radar ? radarFrames       : satelliteFrames
        let index  : Int             = mode == .radar ? radarCurrentIndex : satelliteCurrentIndex
        guard !frames.isEmpty, index < frames.count else { return nil }

        let frame : CloudMapFrame = frames[index]

        guard windVisible && !windSamples.isEmpty else { return frame.image }

        let region : MKCoordinateRegion? = mode == .radar ? radarRegion : satelliteRegion
        guard let region else { return frame.image }

        // Draw wind arrows onto the frame image
        let frameDate : Date = Date(timeIntervalSince1970: TimeInterval(frame.time))

        debugPrint("[Wind] drawing with regionSpanLat: \(region.span.latitudeDelta) regionSpanLon: \(region.span.longitudeDelta) centerLat: \(region.center.latitude) centerLon: \(region.center.longitude)")
        return WindArrowRenderer.draw(onto: frame.image, samples: windSamples, at: frameDate, regionLat: region.span.latitudeDelta, regionLon: region.span.longitudeDelta, centerLat: region.center.latitude, centerLon: region.center.longitude)
    }


    func loadRadarFrames(coordinate: CLLocationCoordinate2D, scale: CGFloat) async {
        radarLoading      = true
        radarFailed       = false
        radarFrames       = []
        radarCurrentIndex = 0

        let tileSize    : Int = 512 // 256/512 are both possible
        let colorScheme : Int = Properties.instance.libreWxrColorScheme ?? Constants.DEFAULT_LIBREWXR_COLOR_SCHEME

        guard let manifest = await fetchManifest(),
              let (baseMap, baseRegion) = await fetchBaseMap(coordinate: coordinate, scale: scale)
        else {
            radarLoading = false
            radarFailed  = true
            return
        }

        let tiles   = tilesCovering(region: baseRegion, zoom: zoomLevel)
        let past    = manifest.radar.past.map    { ($0.time, $0.path, false) }
        let nowcast = manifest.radar.nowcast.map { ($0.time, $0.path, true)  }

        let frames: [CloudMapFrame] = await withTaskGroup(of: CloudMapFrame?.self) { group in
            for (time, path, isNowcast) in past + nowcast {
                group.addTask { [weak self] in
                    guard let self else { return nil }

                    // Fetch every covering tile concurrently for this frame
                    let overlays: [(tile: MapTile, image: UIImage)] = await withTaskGroup(of: (MapTile, UIImage)?.self) { tileGroup in
                        for tile in tiles {
                            tileGroup.addTask {
                                guard let url = tile.libreWxrURL(host: manifest.host, path: path, colorScheme: colorScheme, tileSize: tileSize),
                                      let img = await self.fetchTileImage(from: url)
                                else { return nil }
                                return (tile, img)
                            }
                        }
                        var results: [(MapTile, UIImage)] = []
                        for await result in tileGroup { if let result { results.append(result) } }
                        return results
                    }

                    guard !overlays.isEmpty else { return nil }

                    let composited = self.composite(base: baseMap, overlays: overlays, region: baseRegion, alpha: 0.85)
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
        radarRegion  = baseRegion

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
              let (base, baseRegion) = await fetchBaseMap(coordinate: coordinate, scale: scale)
        else {
            satelliteLoading = false
            satelliteFailed  = true
            return
        }

        let tiles = tilesCovering(region: baseRegion, zoom: zoomLevel)

        let frames: [CloudMapFrame] = await withTaskGroup(of: CloudMapFrame?.self) { group in
            for frame in satellite.infrared {
                group.addTask { [weak self] in
                    guard let self else { return nil }

                    let overlays: [(tile: MapTile, image: UIImage)] = await withTaskGroup(of: (MapTile, UIImage)?.self) { tileGroup in
                        for tile in tiles {
                            tileGroup.addTask {
                                guard let url = tile.libreWxrSatelliteURL(host: manifest.host, path: frame.path),
                                      let img = await self.fetchTileImage(from: url)
                                else { return nil }
                                return (tile, img)
                            }
                        }
                        var results: [(MapTile, UIImage)] = []
                        for await result in tileGroup { if let result { results.append(result) } }
                        return results
                    }

                    guard !overlays.isEmpty else { return nil }

                    let composited = self.composite(base: base, overlays: overlays, region: baseRegion, alpha: 0.9)
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
        satelliteRegion  = baseRegion

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

    // Returns the snapshotted base map image together with the exact geographic
    // region it covers. Returning the region alongside the image (rather than
    // stashing it in shared instance state) avoids a data race when radar and
    // satellite loads run concurrently via loadAll.
    private func fetchBaseMap(coordinate: CLLocationCoordinate2D, scale: CGFloat) async -> (UIImage, MKCoordinateRegion)? {
        let region   : MKCoordinateRegion = MKCoordinateRegion(center: coordinate, latitudinalMeters: 250_000, longitudinalMeters: 250_000)
        let tileSize : CGFloat            = 512

        let options            = MKMapSnapshotter.Options()
        options.region         = region
        options.size           = CGSize(width: tileSize, height: tileSize)
        options.scale          = scale
        options.mapType        = .standard
        options.showsBuildings = false

        guard let image = try? await MKMapSnapshotter(options: options).start().image.tonal else { return nil }
        return (image, region)
    }

    nonisolated private func fetchTileImage(from url: URL) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }
        return UIImage(data: data)
    }

    // Returns every XYZ tile at `zoom` whose bounds intersect `region`.
    // A single 512x512 tile rarely covers the full ~250km base-map region,
    // so the caller must fetch and composite the whole covering set — not
    // just the one tile nearest `coordinate` — or the overlay will be
    // undersized and offset relative to the base map.
    nonisolated private func tilesCovering(region: MKCoordinateRegion, zoom: Int) -> [MapTile] {
        let regNorth = region.center.latitude  + region.span.latitudeDelta  / 2
        let regSouth = region.center.latitude  - region.span.latitudeDelta  / 2
        let regWest  = region.center.longitude - region.span.longitudeDelta / 2
        let regEast  = region.center.longitude + region.span.longitudeDelta / 2

        let n = pow(2.0, Double(zoom))
        func xTile(_ lon: Double) -> Int { Int(floor((lon + 180.0) / 360.0 * n)) }
        func yTile(_ lat: Double) -> Int {
            let rad = lat * .pi / 180.0
            return Int(floor((1.0 - log(tan(rad) + 1.0 / cos(rad)) / .pi) / 2.0 * n))
        }

        let xMin = max(0, xTile(regWest)),  xMax = min(Int(n) - 1, xTile(regEast))
        let yMin = max(0, yTile(regNorth)), yMax = min(Int(n) - 1, yTile(regSouth))

        var tiles: [MapTile] = []
        guard xMin <= xMax, yMin <= yMax else { return tiles }
        for x in xMin...xMax {
            for y in yMin...yMax {
                tiles.append(MapTile(x: x, y: y, z: zoom)) // NB: MapTile's initializer order is (x:, y:, z:)
            }
        }
        return tiles
    }

    // Composites the base map with one or more overlay tiles, each positioned
    // independently via Mercator projection against `region`. Supports an
    // arbitrary tile mosaic rather than assuming a single tile fills the canvas.
    nonisolated private func composite(base: UIImage, overlays: [(tile: MapTile, image: UIImage)], region: MKCoordinateRegion, alpha: CGFloat) -> UIImage {
        let size     : CGSize                  = base.size
        let renderer : UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: size)

        func mercY(_ lat: Double) -> Double {
            let rad : Double = lat * .pi / 180.0
            return log(tan(.pi / 4.0 + rad / 2.0))
        }

        let regNorth      : CGFloat = region.center.latitude  + region.span.latitudeDelta  / 2
        let regSouth      : CGFloat = region.center.latitude  - region.span.latitudeDelta  / 2
        let regWest       : CGFloat = region.center.longitude - region.span.longitudeDelta / 2
        let regEast       : CGFloat = region.center.longitude + region.span.longitudeDelta / 2
        let mercRegNorth  : CGFloat = mercY(regNorth)
        let mercRegSouth  : CGFloat = mercY(regSouth)
        let mercRegHeight : CGFloat = mercRegNorth - mercRegSouth

        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))

            for (tile, overlayImg) in overlays {
                let n         : Double = pow(2.0, Double(tile.z))
                let tileNorth : Double = atan(sinh(.pi * (1.0 - 2.0 * Double(tile.y)     / n))) * 180.0 / .pi
                let tileSouth : Double = atan(sinh(.pi * (1.0 - 2.0 * Double(tile.y + 1) / n))) * 180.0 / .pi
                let tileWest  : Double = Double(tile.x)     / n * 360.0 - 180.0
                let tileEast  : Double = Double(tile.x + 1) / n * 360.0 - 180.0

                let mercTileNorth : CGFloat = mercY(tileNorth)
                let mercTileSouth : CGFloat = mercY(tileSouth)

                let x : CGFloat = CGFloat((tileWest  - regWest)  / (regEast - regWest))    * size.width
                let y : CGFloat = CGFloat((mercRegNorth - mercTileNorth) / mercRegHeight)  * size.height
                let w : CGFloat = CGFloat((tileEast  - tileWest) / (regEast - regWest))    * size.width
                let h : CGFloat = CGFloat((mercTileNorth - mercTileSouth) / mercRegHeight) * size.height

                overlayImg.draw(in: CGRect(x: x, y: y, width: w, height: h), blendMode: .normal, alpha: alpha)
            }

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.3).cgColor] as CFArray, locations: [0.7, 1.0])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: size.width * 0.35, endCenter: CGPoint(x: size.width / 2, y: size.height / 2), endRadius: size.width * 0.72, options: [])
        }
    }
}
