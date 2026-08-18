//
//  CloudMapViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 24.07.26.
//


import Foundation
import SwiftUI
import MapKit


@Observable
class CloudMapViewModel {

    enum State {
        case idle
        case loading
        case loaded(UIImage)
        case failed(String)
    }

    // Cloud, single static image
    var cloudState : State = .idle

    // Radar, animated frames
    var radarFrames       : [CloudMapFrame] = []
    var radarLoading      : Bool            = false
    var radarFailed       : Bool            = false
    var radarCurrentIndex : Int             = 0
    var radarPlaying      : Bool            = true

    // Satellite — animated frames
    var satelliteFrames       : [CloudMapFrame] = []
    var satelliteLoading      : Bool            = false
    var satelliteFailed       : Bool            = false
    var satelliteCurrentIndex : Int             = 0
    var satellitePlaying      : Bool            = true

    private let zoomLevel          : Int    = 7
    private let libreWxrBaseURL    : String = "http://hansolo.eu:8081"
    private let manifestURL        : String = "http://hansolo.eu:8081/public/weather-maps.json"


    func loadAll(coordinate: CLLocationCoordinate2D, apiKey: String, scale: CGFloat) async {
        async let cloudTask     : Void = loadCloud(coordinate: coordinate, apiKey: apiKey, scale: scale)
        async let radarTask     : Void = loadRadarFrames(coordinate: coordinate, scale: scale)
        async let satelliteTask : Void = loadSatelliteFrames(coordinate: coordinate, scale: scale)
        _ = await (cloudTask, radarTask, satelliteTask)
    }

    func loadCloud(coordinate: CLLocationCoordinate2D, apiKey: String, scale: CGFloat) async {
        cloudState = .loading

        async let baseTask = fetchBaseMap(coordinate: coordinate, scale: scale)
        async let tileTask = fetchCloudTile(coordinate: coordinate, apiKey: apiKey)
        let (base, tile)   = await (baseTask, tileTask)

        guard let base else {
            cloudState = .failed("Could not generate map snapshot")
            return
        }

        let boostedTile = tile.map { Helper.boostCloudOpacity($0, factor: 1.5) }
        cloudState = .loaded(composite(base: base, overlay: boostedTile, alpha: 0.75))
    }

    func loadRadarFrames(coordinate: CLLocationCoordinate2D, scale: CGFloat) async {
        radarLoading      = true
        radarFailed       = false
        radarFrames       = []
        radarCurrentIndex = 0
        
        let colorScheme : Int = Properties.instance.libreWxrColorScheme!

        guard let manifest : LibreWxrResponse = await fetchManifest() else {
            radarLoading = false
            radarFailed  = true
            return
        }

        guard let base : UIImage = await fetchBaseMap(coordinate: coordinate, scale: scale) else {
            radarLoading = false
            radarFailed  = true
            return
        }

        let tile      : MapTile = MapTile.tile(for: coordinate, zoom: zoomLevel)
        let past      = manifest.radar.past.map { ($0.time, $0.path, false) }
        let nowcast   = manifest.radar.nowcast.map { ($0.time, $0.path, true)  }
        let allFrames = past + nowcast

        let frames : [CloudMapFrame] = await withTaskGroup(of: CloudMapFrame?.self) { group in
            for (time, path, isNowcast) in allFrames {
                group.addTask { [weak self] in
                    guard let self,
                          let url   = tile.libreWxrURL(host: manifest.host, path: path, colorScheme: colorScheme),
                          let tileImg = await self.fetchTileImage(from: url)
                    else { return nil }
                    let composited = self.composite(base: base, overlay: tileImg, alpha: 0.85)
                    return CloudMapFrame(time: time, image: composited, isNowcast: isNowcast)
                }
            }
            var results: [CloudMapFrame] = []
            for await frame in group {
                if let frame { results.append(frame) }
            }
            return results.sorted { $0.time < $1.time }
        }

        radarFrames   = frames
        radarLoading  = false
        radarFailed   = frames.isEmpty

        // Start at most recent past frame
        if let lastPast = frames.lastIndex(where: { !$0.isNowcast }) {
            radarCurrentIndex = lastPast
        }
    }

    func advanceRadarFrame() {
        guard !radarFrames.isEmpty else { return }
        radarCurrentIndex = (radarCurrentIndex + 1) % radarFrames.count
    }

    var currentRadarFrame: CloudMapFrame? {
        guard !radarFrames.isEmpty, radarCurrentIndex < radarFrames.count else { return nil }
        return radarFrames[radarCurrentIndex]
    }

    func frameTimeLabel(for frame: CloudMapFrame) -> String {
        let date      : Date = Date(timeIntervalSince1970: TimeInterval(frame.time))
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

        guard let manifest = await fetchManifest(),
              let satellite = manifest.satellite,
              !satellite.infrared.isEmpty
        else {
            // LibreWXR satellite unavailable — fall back to OWM cloud tile
            satelliteLoading = false
            satelliteFailed  = true
            return
        }

        guard let base : UIImage = await fetchBaseMap(coordinate: coordinate, scale: scale) else {
            satelliteLoading = false
            satelliteFailed  = true
            return
        }

        let tile   : MapTile         = MapTile.tile(for: coordinate, zoom: zoomLevel)
        let frames : [CloudMapFrame] = await withTaskGroup(of: CloudMapFrame?.self) { group in
            for infraredFrame in satellite.infrared {
                group.addTask { [weak self] in
                    guard let self,
                          let url     = tile.libreWxrSatelliteURL(host: manifest.host, path: infraredFrame.path),
                          let tileImg = await self.fetchTileImage(from: url)
                    else { return nil }
                    let composited = self.composite(base: base, overlay: tileImg, alpha: 0.9)
                    return CloudMapFrame(time: infraredFrame.time, image: composited, isNowcast: false)
            }
        }
            var results: [CloudMapFrame] = []
            for await frame in group {
                if let frame { results.append(frame) }
            }
            return results.sorted { $0.time < $1.time }
        }

        satelliteFrames   = frames
        satelliteLoading  = false
        satelliteFailed   = frames.isEmpty

        // Start at most recent frame
        if !frames.isEmpty {
            satelliteCurrentIndex = frames.count - 1
        }
    }

    func advanceSatelliteFrame() {
        guard !satelliteFrames.isEmpty else { return }
        satelliteCurrentIndex = (satelliteCurrentIndex + 1) % satelliteFrames.count
    }

    var currentSatelliteFrame: CloudMapFrame? {
        guard !satelliteFrames.isEmpty, satelliteCurrentIndex < satelliteFrames.count else { return nil }
        return satelliteFrames[satelliteCurrentIndex]
    }


    private func fetchManifest() async -> LibreWxrResponse? {
        guard let url = URL(string: manifestURL) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(LibreWxrResponse.self, from: data)
        } catch {
            return nil
        }
    }

    private func fetchBaseMap(coordinate: CLLocationCoordinate2D, scale: CGFloat) async -> UIImage? {
        let options            = MKMapSnapshotter.Options()
        options.region         = MKCoordinateRegion(center: coordinate, latitudinalMeters: 250_000, longitudinalMeters: 250_000)
        options.size           = CGSize(width: 360, height: 360)
        options.scale          = scale
        options.mapType        = .standard
        options.showsBuildings = false
        return try? await MKMapSnapshotter(options: options).start().image
    }

    private func fetchCloudTile(coordinate: CLLocationCoordinate2D, apiKey: String) async -> UIImage? {
        let tile : MapTile = MapTile.tile(for: coordinate, zoom: zoomLevel)
        guard let url : URL = tile.owmCloudURL(apiKey: apiKey) else { return nil }
        return await fetchTileImage(from: url)
    }

    private func fetchTileImage(from url: URL) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http : HTTPURLResponse = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return nil }
            return UIImage(data: data)
        }

    nonisolated private func composite(base: UIImage, overlay: UIImage?, alpha: CGFloat) -> UIImage {
        let size     : CGSize                  = base.size
        let renderer : UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))
            if let overlay {
                overlay.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: alpha)
            }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.3).cgColor] as CFArray, locations: [0.7, 1.0])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: size.width * 0.35, endCenter: CGPoint(x: size.width / 2, y: size.height / 2), endRadius: size.width * 0.72, options: [])
        }
    }
}
