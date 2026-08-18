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

    var cloudState : State = .idle
    var radarState : State = .idle

    private let zoomLevel = 7  // regional view ~250km across


    func loadAll(coordinate: CLLocationCoordinate2D, apiKey: String, scale: CGFloat) async {
        async let cloudTask = loadCloud(coordinate: coordinate, apiKey: apiKey, scale: scale)
        async let radarTask = loadRadar(coordinate: coordinate, scale: scale)
        _ = await (cloudTask, radarTask)
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

    func loadRadar(coordinate: CLLocationCoordinate2D, scale: CGFloat) async {
        radarState = .loading

        async let baseTask      = fetchBaseMap(coordinate: coordinate, scale: scale)
        //async let frameTask     = fetchLatestRadarFrame()
        //let (base, frame)   = await (baseTask, frameTask)
        async let timestampTask = fetchLatestRadarTimestamp()
        let (base, timestamp)   = await (baseTask, timestampTask)

        guard let base else {
            radarState = .failed("Could not generate map snapshot")
            return
        }

        var radarTile: UIImage?
        if let ts = timestamp {
            radarTile = await fetchRadarTile(coordinate: coordinate, timestamp: ts)
        }
        if radarTile == nil {
            radarState = .failed("Radar data unavailable")
            return
        }
        
        radarState = .loaded(composite(base: base, overlay: radarTile, alpha: 0.85))
        
        /*
        if let frame {
            let tile = MapTile.tile(for: coordinate, zoom: zoomLevel)
            if let url = tile.libreWxrURL(host: frame.host, path: frame.path) {
                radarTile = await fetchTileImage(from: url)
            }
        }

        guard let radarTile else {
            radarState = .failed("Radar data unavailable")
            return
        }

        radarState = .loaded(composite(base: base, overlay: radarTile, alpha: 0.85))
        */
    }

    private func fetchLatestRadarFrame() async -> (host: String, path: String)? {        
        guard let url = URL(string: "http://hansolo.eu:8081/public/weather-maps.json") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response  = try JSONDecoder().decode(LibreWxrResponse.self, from: data)
            guard let last = response.radar.past.last else { return nil }
            return (response.host, last.path)
        } catch {
            return nil
        }
    }
    
    private func fetchLatestRadarTimestamp() async -> Int? {
        guard let url = URL(string: "http://hansolo.eu:8081/public/weather-maps.json") else { return nil }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response  = try JSONDecoder().decode(LibreWxrResponse.self, from: data)
                return response.radar.past.last?.time
            } catch {
                return nil
            }
    }
    
    private func fetchBaseMap(coordinate: CLLocationCoordinate2D, scale: CGFloat) async -> UIImage? {
        let options            = MKMapSnapshotter.Options()
        options.region         = MKCoordinateRegion(center: coordinate, latitudinalMeters: 250_000, longitudinalMeters: 250_000) // ~250km
        options.size           = CGSize(width: 360, height: 360)
        options.scale          = scale
        options.mapType        = .standard
        options.showsBuildings = false

        do {
            let snapshot = try await MKMapSnapshotter(options: options).start()
            return snapshot.image
        } catch {
            return nil
        }
    }
    
    private func fetchCloudTile(coordinate: CLLocationCoordinate2D, apiKey: String) async -> UIImage? {
        let tile : MapTile = MapTile.tile(for: coordinate, zoom: zoomLevel)
        guard let url : URL = tile.owmCloudURL(apiKey: apiKey) else { return nil }
        return await fetchTileImage(from: url)
    }
 
    private func fetchRadarTile(coordinate: CLLocationCoordinate2D, timestamp: Int) async -> UIImage? {
        let tile : MapTile = MapTile.tile(for: coordinate, zoom: zoomLevel)
        guard let url : URL = tile.libreWxrURL(timestamp: timestamp) else { return nil }
        return await fetchTileImage(from: url)
    }
    
    private func fetchTileImage(from url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http : HTTPURLResponse = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
    
    private func composite(base: UIImage, overlay: UIImage?, alpha: CGFloat) -> UIImage {
        let size     : CGSize                  = base.size
        let renderer : UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))

            if let overlay {
                overlay.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: alpha)
            }

            // Subtle dark vignette
            let gradient : CGGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.3).cgColor] as CFArray, locations: [0.7, 1.0])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: size.width * 0.35, endCenter: CGPoint(x: size.width / 2, y: size.height / 2), endRadius: size.width * 0.72, options: [])
        }
    }
}

