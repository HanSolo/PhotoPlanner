//
//  WindOverlay.swift
//  PhotoPlanner
//
//  Fetches hourly wind data from Open-Meteo for a 5x5 grid
//  covering the map snapshot region, then draws wind arrows
//  on top of a composited UIImage.
//
//  Open-Meteo is free, no API key required.
//  One call per grid point fetches all hourly values at once,
//  so scrubbing frames uses cached data — no additional calls.

import Foundation
import UIKit
import CoreLocation


private func fetchWindFromNetwork(lat: Double, lon: Double) async -> WindSample? {
    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
    components?.queryItems = [
        URLQueryItem(name: "latitude",        value: String(format: "%.4f", lat)),
        URLQueryItem(name: "longitude",       value: String(format: "%.4f", lon)),
        URLQueryItem(name: "hourly",          value: "wind_speed_10m,wind_direction_10m"),
        URLQueryItem(name: "wind_speed_unit", value: "ms"),
        URLQueryItem(name: "forecast_days",   value: "2"),
        URLQueryItem(name: "past_days",       value: "1"),
        URLQueryItem(name: "timezone",        value: "UTC")
    ]
    guard let url = components?.url else { return nil }
 
    guard let (data, _) = try? await URLSession.shared.data(from: url),
          let response   = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data)
    else { return nil }
 
    let formatter           = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
 
    var hours : [WindHour] = []
    let times  = response.hourly.time
    let speeds = response.hourly.wind_speed_10m
    let dirs   = response.hourly.wind_direction_10m
 
    for i in 0..<times.count {
        // Open-Meteo returns times as "2026-08-19T00:00" — append timezone suffix
        let timeStr = times[i] + ":00+00:00"
        guard let date  = formatter.date(from: timeStr),
              let speed = speeds[i],
              let dir   = dirs[i]
        else { continue }
        hours.append(WindHour(time: date, speedMs: speed, directionDeg: dir))
    }
 
    return WindSample(latitude: lat, longitude: lon, hourly: hours)
}

actor WindFetcher {
 
    private var cache       : [String: WindSample] = [:]
    private var cacheTime   : Date                 = .distantPast
    private let cacheMaxAge : TimeInterval         = 3600   // 1 hour
 
    // Fetches wind samples for a 5x5 grid covering the given region.
    func fetchGrid(center: CLLocationCoordinate2D, spanLat: Double, spanLon: Double) async -> [WindSample] {
        if Date().timeIntervalSince(cacheTime) > cacheMaxAge { cache = [:] }

        let gridSize : Int = 5
        let latStep  : Double = spanLat / Double(gridSize - 1)
        let lonStep  : Double = spanLon / Double(gridSize - 1)
        let startLat : Double = center.latitude  - spanLat / 2
        let startLon : Double = center.longitude - spanLon / 2

        // Separate cached from uncached (done on actor before TaskGroup)
        var cachedSamples : [WindSample]                 = []
        var pointsToFetch : [(lat: Double, lon: Double)] = []

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let lat : Double = startLat + Double(row) * latStep
                let lon : Double = startLon + Double(col) * lonStep
                let key : String = String(format: "%.3f,%.3f", lat, lon)
                if let cached = cache[key] {
                    cachedSamples.append(cached)   // actor-isolated read, safe here
                } else {
                    pointsToFetch.append((lat, lon))
                }
            }
        }

        // Only fetch uncached points in parallel (no actor state access inside TaskGroup)
        let fetchedSamples: [WindSample] = await withTaskGroup(of: WindSample?.self) { group in
            for point in pointsToFetch {
                group.addTask {
                    await fetchWindFromNetwork(lat: point.lat, lon: point.lon)
                }
            }
            var results: [WindSample] = []
            for await sample in group {
                if let sample { results.append(sample) }
            }
            return results
        }

        // Write fetched results to cache (back on actor, safe)
        for sample in fetchedSamples {
            let key : String = String(format: "%.3f,%.3f", sample.latitude, sample.longitude)
            cache[key] = sample
        }

        cacheTime = Date()
        return cachedSamples + fetchedSamples
    }
}
