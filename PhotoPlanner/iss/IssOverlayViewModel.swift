//
//  IssOverlayViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.09.26.
//

import Foundation
import CoreLocation
import MapKit


@Observable
class IssOverlayViewModel {
    var pathPoints           : [ISSPathPoint]             = []
    var smoothedPathSegments : [[CLLocationCoordinate2D]] = [] // Path split into segments wherever consecutive points cross the antimeridian (±180° longitude), and smoothed via Catmull-Rom interpolation in geographic (lat/lon) space
    var currentPosition      : CLLocationCoordinate2D?    
    
    private let noradId          : Int    = 25544
    private let baseURL          : String = "https://api.wheretheiss.at/v1/satellites"
    private let pathWindowMin    : Int    = 45   // preview window
    private let pathStepMin      : Int    = 5    // resolution: 10 points total (API caps at 10 timestamps)
    private let pathRefreshSec   : Double = 300  // refetch the predicted path every 5 min
    private let liveRefreshSec   : Double = 10   // poll current position every 10s
    private let interpolationSteps : Int  = 8    // extra points per segment for a smooth curve

    private var pathTimer : Timer?
    private var liveTimer : Timer?
    private var loadTask  : Task<Void, Never>?

    
    func show(region: MKCoordinateRegion? = nil) {
        startLiveUpdates()
        startPathUpdates()
    }

    func hide() {
        pathTimer?.invalidate();
        pathTimer            = nil
        liveTimer?.invalidate();
        liveTimer            = nil
        loadTask?.cancel();
        loadTask             = nil
        pathPoints           = []
        smoothedPathSegments = []
        currentPosition      = nil
    }

    // Live position (10s poll)
    private func startLiveUpdates() {
        liveTimer?.invalidate()
        Task { await fetchCurrentPosition() }
        liveTimer = Timer.scheduledTimer(withTimeInterval: liveRefreshSec, repeats: true) { [weak self] _ in
            Task { await self?.fetchCurrentPosition() }
        }
    }

    private func fetchCurrentPosition() async {
        guard let url = URL(string: "\(baseURL)/\(noradId)") else { return }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ISSPositionResponse.self, from: data)
        else { return }

        await MainActor.run {
            self.currentPosition = CLLocationCoordinate2D(latitude: decoded.latitude, longitude: decoded.longitude)
        }
    }

    // Predicted path (45min window, single batched request)
    private func startPathUpdates() {
        pathTimer?.invalidate()
        loadTask?.cancel()
        loadTask  = Task { await fetchPath() }
        pathTimer = Timer.scheduledTimer(withTimeInterval: pathRefreshSec, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.loadTask?.cancel()
            self.loadTask = Task { await self.fetchPath() }
        }
    }

    private func fetchPath() async {
        guard !Task.isCancelled else { return }

        let now        : Date  = Date()
        let timestamps : [Int] = stride(from: 0, through: pathWindowMin, by: pathStepMin).map { minute in
            Int(now.addingTimeInterval(Double(minute) * 60).timeIntervalSince1970)
        }
        let timestampParam = timestamps.map(String.init).joined(separator: ",")

        guard let url              : URL = URL(string: "\(baseURL)/\(noradId)/positions?timestamps=\(timestampParam)") else { return }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http    = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode([ISSPositionResponse].self, from: data)
        else { return }

        guard !Task.isCancelled else { return }

        let points : [ISSPathPoint] = decoded
            .sorted { $0.timestamp < $1.timestamp }
            .map { ISSPathPoint(coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude), timestamp: Date(timeIntervalSince1970: $0.timestamp)) }

        let segments : [[CLLocationCoordinate2D]] = splitAtAntimeridian(points.map { $0.coordinate })
        let smoothed : [[CLLocationCoordinate2D]] = segments.map { smoothCoordinates($0) }

        await MainActor.run {
            self.pathPoints = points
            self.smoothedPathSegments = smoothed
        }
    }

    private func splitAtAntimeridian(_ coordinates: [CLLocationCoordinate2D]) -> [[CLLocationCoordinate2D]] {
        var segments    : [[CLLocationCoordinate2D]] = [[]]
        var previousLon : Double?                    = nil
        for coord in coordinates {
            if let prevLon = previousLon, abs(coord.longitude - prevLon) > 180 {
                segments.append([])
            }
            segments[segments.count - 1].append(coord)
            previousLon = coord.longitude
        }
        return segments.filter { $0.count > 1 }
    }

    // Catmull-Rom interpolation directly in lat/lon space
    private func smoothCoordinates(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }

        var result : [CLLocationCoordinate2D] = []

        for i in 0..<(points.count - 1) {
            let p0 = i == 0 ? points[i] : points[i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

            result.append(p1)

            for step in 1..<interpolationSteps {
                let t : Double = Double(step) / Double(interpolationSteps)
                result.append(catmullRom(p0: p0, p1: p1, p2: p2, p3: p3, t: t))
            }
        }
        result.append(points[points.count - 1])
        return result
    }

    private func catmullRom(p0: CLLocationCoordinate2D, p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, p3: CLLocationCoordinate2D, t: Double) -> CLLocationCoordinate2D {
        func interpolate(_ v0: Double, _ v1: Double, _ v2: Double, _ v3: Double, _ t: Double) -> Double {
            let t2 : Double = t * t
            let t3 : Double = t2 * t
            return 0.5 * ((2 * v1) + (-v0 + v2) * t + (2*v0 - 5*v1 + 4*v2 - v3) * t2 + (-v0 + 3*v1 - 3*v2 + v3) * t3)
        }

        let lat : Double = interpolate(p0.latitude,  p1.latitude,  p2.latitude,  p3.latitude,  t)
        let lon : Double = interpolate(p0.longitude, p1.longitude, p2.longitude, p3.longitude, t)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
