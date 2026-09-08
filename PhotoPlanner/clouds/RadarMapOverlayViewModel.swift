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
    private var loadTask     : Task<Void, Never>?
    private var refreshTimer : Timer?
    
    // Adaptive tile resolution. Switching to 512px is only worthwhile once the
    // mosaic (bounded by tilesForRegion + the 35 tile cap) is small enough that
    // the 4x memory cost per tile (512² vs 256²) stays within budget. Zoom is
    // clamped to 4...9 in zoomLevel(for:), so 8 sits one step below the ceiling.
    //
    // Hysteresis: switch up to 512px only at zoom >= highResZoomIn, switch back
    // down to 256px only once zoom drops below highResZoomOut. The gap between
    // the two prevents rapid re-fetching at alternating resolutions when the
    // user pinch-zooms back and forth across a single threshold.
    private let highResZoomIn   : Int = 8   // switch to 512px at/above this zoom
    private let highResZoomOut  : Int = 6   // fall back to 256px below this zoom
    private var currentTileSize : Int = 256
 
    // Hard byte ceiling for one fetched mosaic's decoded memory (RGBA, 4 bytes/px).
    // Used to veto a 512px fetch that would exceed budget even after the zoom
    // hysteresis says "go high-res", e.g. a wide region still zoomed to 8.
    private let maxMosaicBytes : Int = 60 * 1024 * 1024 // 60MB
 
    private func resolvedTileSize(for zoom: Int, tileCount: Int) -> Int {
        if currentTileSize == 256 && zoom >= highResZoomIn {
            currentTileSize = 512
        } else if currentTileSize == 512 && zoom < highResZoomOut {
            currentTileSize = 256
        }
 
        // Even within hysteresis, don't let a large mosaic blow the memory budget.
        let candidateBytes = tileCount * currentTileSize * currentTileSize * 4
        if candidateBytes > maxMosaicBytes { return 256 }
        return currentTileSize
    }
    
    var currentOpacity: Double {
        guard let region = currentRegion else { return 0.65 }
        // Derive zoom level from longitude span.
        // Below plateauZoom: stay fully opaque (0.95), colors stay strong for
        // most of the zoom range. Above it, fade non-linearly down to 0.35 by
        // maxZoom, with the fade concentrated near the top of the range rather
        // than spread evenly, so it only gets translucent when zoomed in very far.
        let zoom    : Double = log2(360.0 / region.span.longitudeDelta)
        let plateauZoom : Double = 7.0   // no fading at/below this zoom
        let maxZoom     : Double = 9.0   // fully faded (0.35) at/above this zoom
        let fadeExponent: Double = 3.0   // higher = fade concentrated closer to maxZoom
 
        guard zoom > plateauZoom else { return 0.95 }
 
        let clamped : Double = max(plateauZoom, min(maxZoom, zoom))
        let t       : Double = (clamped - plateauZoom) / (maxZoom - plateauZoom) // 0.0 at plateauZoom, 1.0 at maxZoom
        let eased   : Double = pow(t, fadeExponent)
        return 0.95 - eased * (0.95 - 0.35)                                      // 0.95...0.35
    }

       
    func startAutoRefresh(region: MKCoordinateRegion, canvasSize: CGSize) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
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
                        
        let colorScheme  = Properties.instance.libreWxrColorScheme ?? 13
        let host         = response.host
        let path         = lastFrame.path
        let resolvedSize = resolvedTileSize(for: zoom, tileCount: tileList.count)
 
        // Fetch all tiles in parallel
        let fetched: [(MapTile, UIImage)] = await withTaskGroup(of: (MapTile, UIImage)?.self) { group in
            for tile in tileList {
                group.addTask {
                    guard !Task.isCancelled else { return nil }
                    let urlStr = "\(host)\(path)/\(resolvedSize)/\(tile.z)/\(tile.x)/\(tile.y)/\(colorScheme)/1_1.png"
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
