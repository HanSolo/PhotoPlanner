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

    var state: State = .idle

    private let zoomLevel = 7   // regional view ~250km across

    
    func load(coordinate: CLLocationCoordinate2D, apiKey: String, scale: CGFloat) async {
        state = .loading

        async let baseImageTask = fetchBaseMap(coordinate: coordinate, scale: scale)
        async let cloudTileTask = fetchCloudTile(coordinate: coordinate, apiKey: apiKey)
                
        let (baseImage, cloudTile) = await (baseImageTask, cloudTileTask)
                
        guard let base = baseImage else {
            state = .failed("Could not generate map snapshot")
            return
        }

        let composite = composite(base: base, overlay: cloudTile)
        state = .loaded(composite)
    }
    

    private func fetchBaseMap(coordinate: CLLocationCoordinate2D, scale: CGFloat) async -> UIImage? {        
        let options            = MKMapSnapshotter.Options()
        options.region         = MKCoordinateRegion(center: coordinate, latitudinalMeters: 250_000, longitudinalMeters: 250_000) // ~250km
        options.size           = CGSize(width: 300, height: 300)
        options.scale          = scale
        options.mapType        = .standard
        options.showsBuildings = false

        do {
            let snapshotter = MKMapSnapshotter(options: options)
            let snapshot    = try await snapshotter.start()
            return snapshot.image
        } catch {
            return nil
        }
    }
    

    private func fetchCloudTile(coordinate: CLLocationCoordinate2D, apiKey: String) async -> UIImage? {
        let tile = MapTile.tile(for: coordinate, zoom: zoomLevel)
        guard let url = tile.owmURL(apiKey: apiKey) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }


    private func composite(base: UIImage, overlay: UIImage?) -> UIImage {
        let size     = base.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))

            if let cloud = overlay {
                let scale      : Double = 1.0
                let tileSize   : CGSize = CGSize(width: size.width / scale, height: size.height / scale)
                let tileOrigin : CGPoint = CGPoint(x: (size.width - tileSize.width) / 2, y: (size.height - tileSize.height) / 2)
                
                let boostedCloud = Helper.boostCloudOpacity(cloud, factor: 1.5) // 3.0 is too much
                boostedCloud.draw(in: CGRect(origin: tileOrigin, size: tileSize), blendMode: .normal, alpha: 1.0)                                
            }
        }
    }
}

