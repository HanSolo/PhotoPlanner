//
//  RadarMapOverlayViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 31.08.26.
//
import Foundation
import SwiftUI
import MapKit


@Observable
class RadarMapOverlayViewModel {
    var isVisible     : Bool                 = Properties.instance.showWeatherRadar!
    var isLoading     : Bool                 = false
    var tiles         : [(MapTile, UIImage)] = []
    var canvasSize    : CGSize               = .zero
    var tooManyTiles  : Bool                 = false
    var currentRegion : MKCoordinateRegion?

    private let libreWxrHost : String = "http://hansolo.eu:8081"
    private let manifestURL  : String = "http://hansolo.eu:8081/public/weather-maps.json"
    private let tileSize     : Int    = 256
    private var loadTask     : Task<Void, Never>?
    private var refreshTimer : Timer?
    
    var currentOpacity: Double {
        guard let region = currentRegion else { return 0.65 }
        // Derive zoom level from longitude span
        // zoom 5 (very zoomed out) → 0.95 opacity
        // zoom 9 (close in) → 0.35 opacity
        let zoom    : Double = log2(360.0 / region.span.longitudeDelta)
        let clamped : Double = max(5.0, min(9.0, zoom))
        // Linear interpolation between zoom 5 (0.95) and zoom 9 (0.35)
        let t : Double = (clamped - 5.0) / (9.0 - 5.0) // 0.0 at zoom 5, 1.0 at zoom 9
        return 0.95 - t * (0.95 - 0.35)                // 0.95...0.35
    }

       
    func startAutoRefresh(region: MKCoordinateRegion, canvasSize: CGSize) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.startLoad(region: region, canvasSize: canvasSize)
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // Show radar for the given region. Cancels any in-flight load
    func load(region: MKCoordinateRegion, canvasSize: CGSize) {
        isVisible       = true
        currentRegion   = region
        self.canvasSize = canvasSize
        startLoad(region: region, canvasSize: canvasSize)
        startAutoRefresh(region: region, canvasSize: canvasSize)
    }

    // Hide overlay and cancel any in-flight load
    func hide() {
        isVisible = false
        loadTask?.cancel()
        loadTask  = nil
        tiles     = []
        isLoading = false
        stopAutoRefresh()
    }

    // Called when map pan/zoom ends. Clears old tiles, reloads if visible
    func mapDidSettle(region: MKCoordinateRegion, canvasSize: CGSize) {
        guard isVisible else { return }
        currentRegion   = region
        self.canvasSize = canvasSize
        tiles           = []   // clear stale tiles immediately
        startLoad(region: region, canvasSize: canvasSize)
    }

    // Called during pan/zoom, hides tiles but keeps isVisible state.
    func mapDidMove() {
        tiles = []
    }
    
    private func startLoad(region: MKCoordinateRegion, canvasSize: CGSize) {
        loadTask?.cancel()
        loadTask = Task { await self.fetchTiles(region: region, canvasSize: canvasSize) }
    }

    private func fetchTiles(region: MKCoordinateRegion, canvasSize: CGSize) async {
        guard !Task.isCancelled else { return }

        isLoading = true

        // Fetch manifest to get latest radar frame path
        guard let manifestData = try? await URLSession.shared.data(from: URL(string: manifestURL)!).0,
              let response     = try? JSONDecoder().decode(LibreWxrResponse.self, from: manifestData),
              let lastFrame    = response.radar.past.last
        else {
            isLoading = false
            return
        }

        guard !Task.isCancelled else { isLoading = false; return }
        
        let zoom     = max(5, zoomLevel(for: region))  // minimum zoom 5
        let tileList = tilesForRegion(region, zoom: zoom)
        guard tileList.count <= 35 else {              // Cap tiles at 35 to avoid out of memory error
            await MainActor.run {
                self.tooManyTiles = true
                self.isLoading    = false
            }
            return
        }
        await MainActor.run { self.tooManyTiles = false }
                        
        let colorScheme = Properties.instance.libreWxrColorScheme ?? 8
        let host        = response.host
        let path        = lastFrame.path

        // Fetch all tiles in parallel
        let fetched: [(MapTile, UIImage)] = await withTaskGroup(of: (MapTile, UIImage)?.self) { group in
            for tile in tileList {
                group.addTask {
                    guard !Task.isCancelled else { return nil }
                    let urlStr = "\(host)\(path)/\(self.tileSize)/\(tile.z)/\(tile.x)/\(tile.y)/\(colorScheme)/1_1.png"
                    guard let url           = URL(string: urlStr),
                          let (data, resp)  = try? await URLSession.shared.data(from: url),
                          let http          = resp as? HTTPURLResponse,
                          http.statusCode   == 200,
                          let img           = UIImage(data: data)
                    else { return nil }
                    
                    return (tile, img)
                }
            }

            var results: [(MapTile, UIImage)] = []
            for await result in group {
                if let r = result { results.append(r) }
            }
            return results
        }

        guard !Task.isCancelled else { isLoading = false; return }

        tiles     = fetched
        isLoading = false
    }
    
    // Derives an appropriate XYZ zoom level from the visible map span
    // Larger span = lower zoom = fewer tiles needed
    private func zoomLevel(for region: MKCoordinateRegion) -> Int {
        // Approximate zoom from longitude span, each zoom level halves the degrees per tile (360° at zoom 0)
        let lonSpan : Double = region.span.longitudeDelta
        let zoom    : Int    = Int(log2(360.0 / lonSpan))
        return max(4, min(9, zoom)) // Clamp to sensible range for radar tiles
    }

    // Returns all XYZ tile indices that cover a geographic bounding box at a given zoom
    private func tilesForRegion(_ region: MKCoordinateRegion, zoom: Int) -> [MapTile] {
        let n = pow(2.0, Double(zoom))

        // Use Mercator Y for latitude to tile conversion — matches map projection
        func lon2x(_ lon: Double) -> Int {
            Int((lon + 180.0) / 360.0 * n)
        }
        func lat2y(_ lat: Double) -> Int {
            let clampedLat = max(-85.0511, min(85.0511, lat))
            let rad = clampedLat * .pi / 180.0
            let mercY = (1.0 - log(tan(rad) + 1.0 / cos(rad)) / .pi) / 2.0
            return Int(mercY * n)
        }

        let minLat = region.center.latitude  - region.span.latitudeDelta  / 2
        let maxLat = region.center.latitude  + region.span.latitudeDelta  / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        let xMin = max(0, lon2x(minLon) - 1)
        let xMax = min(Int(n) - 1, lon2x(maxLon) + 1)
        let yMin = max(0, lat2y(maxLat) - 1)   // maxLat → smallest y (top)
        let yMax = min(Int(n) - 1, lat2y(minLat) + 1)  // minLat → largest y (bottom)

        var tiles: [MapTile] = []
        for x in xMin...xMax {
            for y in yMin...yMax {
                tiles.append(MapTile(x: x, y: y, z: zoom))
            }
        }
        return tiles
    }
}
