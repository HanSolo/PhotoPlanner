//
//  OpenMetoCloudFetcher.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 31.08.26.
//

import Foundation
import CoreLocation


// Cloud layers:
// Low  (0...2 km) : stratus, fog (blocks light, poor for color)
// Mid  (2...6 km) : altocumulus  (sweet spot for dramatic color)
// High (6+ km)    : cirrus       (thin, pastel color)

// Model
struct CloudLayerHour: Sendable {
    let time     : Date
    let lowPct   : Double   // 0...100 stratus/fog layer
    let midPct   : Double   // 0...100 altocumulus layer
    let highPct  : Double   // 0...100 cirrus layer
    let totalPct : Double   // 0...100 total cloud cover

    // A photographer-friendly cloud score derived from the three layers.
    // Mid cloud 30...70% with low cloud <30% is the sweet spot for dramatic color.
    // Low cloud >40% blocks the horizon entirely regardless of other layers.
    nonisolated func cloudScore(shootingTowardSun: Bool, shootingAwaySun: Bool) -> Double {
        let low  : Double = lowPct  / 100.0
        let mid  : Double = midPct  / 100.0
        let high : Double = highPct / 100.0

        // Low cloud is the primary killer — it sits at the horizon and blocks light
        // regardless of what's happening at higher levels
        if low > 0.7 { return 0.05 }   // solid stratus/fog — no color
        if low > 0.5 { return 0.15 }   // heavy low cloud

        // Mid cloud is the sweet spot — illuminated from below at sunrise/sunset
        // producing the dramatic orange/red/purple colors photographers want
        let midScore: Double
        switch mid {
            case ..<0.1    : midScore = shootingTowardSun ? 0.5 : 0.2 // clear (limited canvas)
            case 0.1..<0.3 : midScore = 0.8                           // light mid cloud (good)
            case 0.3..<0.6 : midScore = 1.0                           // optimal mid cloud
            case 0.6..<0.8 : midScore = 0.65                          // heavy mid cloud
            default        : midScore = 0.25                          // overcast mid level
        }

        // High cloud adds diffuse color but reduces contrast
        let highBonus : Double = high > 0.3 ? 0.05 : 0.0

        // Low cloud penalty — even moderate low cloud reduces the score
        let lowPenalty : Double
        switch low {
            case ..<0.15    : lowPenalty = 0.0
            case 0.15..<0.3 : lowPenalty = 0.1
            case 0.3..<0.5  : lowPenalty = 0.25
            default         : lowPenalty = 0.4
        }
        return max(0.0, min(1.0, midScore + highBonus - lowPenalty))
    }

    // Reasoning string for the UI
    nonisolated func reasoning(shootingTowardSun: Bool) -> String? {
        let low  : Double = lowPct  / 100.0
        let mid  : Double = midPct  / 100.0
        let high : Double = highPct / 100.0

        if low > 0.6 { return "Solid low cloud (stratus/fog): horizon likely blocked" }
        if low > 0.4 { return "Heavy low cloud: color burst may be above cloud base" }
        if mid > 0.3 && mid < 0.7 && low < 0.3 { return "Good mid-level cloud canvas: dramatic color likely" }
        if mid > 0.7 { return "Heavy mid cloud: color possible but muted" }
        if high > 0.5 && mid < 0.2 && low < 0.2 { return "High cirrus only: soft pastel color likely" }
        if mid < 0.1 && low < 0.1 && high < 0.1 { return shootingTowardSun ? "Clear sky: clean but limited color" : "Clear sky: nothing to reflect color onto" }
        return nil
    }
}

// OpenMeteo response
private struct OpenMeteoCloudResponse: Decodable, Sendable {
    struct Hourly: Decodable, Sendable {
        let time             : [String]
        let cloud_cover      : [Double?]
        let cloud_cover_low  : [Double?]
        let cloud_cover_mid  : [Double?]
        let cloud_cover_high : [Double?]
    }
    let hourly : Hourly
}

// Fetcher
private func fetchCloudLayersFromNetwork(lat: Double, lon: Double, date: Date) async -> [CloudLayerHour] {
    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
    components?.queryItems = [
        URLQueryItem(name: "latitude",      value: String(format: "%.4f", lat)),
        URLQueryItem(name: "longitude",     value: String(format: "%.4f", lon)),
        URLQueryItem(name: "hourly",        value: "cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high"),
        URLQueryItem(name: "forecast_days", value: "3"),
        URLQueryItem(name: "past_days",     value: "1"),
        URLQueryItem(name: "timezone",      value: "UTC")
    ]
    guard let url = components?.url else { return [] }

    guard let (data, _) = try? await URLSession.shared.data(from: url),
          let response  = try? JSONDecoder().decode(OpenMeteoCloudResponse.self, from: data)
    else { return [] }

    let formatter : DateFormatter    = makeFormatter()
    var hours     : [CloudLayerHour] = []
    let times     : [String]         = response.hourly.time

    for i in 0..<times.count {
        let timeStr = times[i] + ":00+00:00"
        guard let date = formatter.date(from: timeStr) else { continue }

        hours.append(CloudLayerHour(time: date, lowPct: response.hourly.cloud_cover_low[i] ?? 0, midPct: response.hourly.cloud_cover_mid[i] ?? 0, highPct: response.hourly.cloud_cover_high[i] ?? 0, totalPct: response.hourly.cloud_cover[i] ?? 0))
    }
    return hours
}

private func makeFormatter() -> DateFormatter {
    let formatter        : DateFormatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.timeZone   = TimeZone(identifier: "UTC")
    formatter.locale     = Locale(identifier: "en_US_POSIX")
    return formatter
}

actor OpenMeteoCloudFetcher {
    // Cache keyed by "lat,lon", shared across all five sampling points
    private var cache     : [String: [CloudLayerHour]] = [:]
    private var cacheTime : Date                       = .distantPast
    private let maxAge    : TimeInterval               = 3600   // 1 hour

    // Fetches cloud layer data for a coordinate, using cache if fresh.
    func fetch(lat: Double, lon: Double) async -> [CloudLayerHour] {
        if Date().timeIntervalSince(cacheTime) > maxAge { cache = [:] }

        let key = String(format: "%.3f,%.3f", lat, lon)
        if let cached = cache[key] { return cached }

        let result = await fetchCloudLayersFromNetwork(lat: lat, lon: lon, date: Date())
        cache[key] = result
        if cacheTime == .distantPast { cacheTime = Date() }
        return result
    }

    // Finds the closest hour to a given date from fetched data.
    func cloudLayers(for coordinate: CLLocationCoordinate2D, at date: Date) async -> CloudLayerHour? {
        let hours = await fetch(lat: coordinate.latitude, lon: coordinate.longitude)
        return hours.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) })
    }
}
