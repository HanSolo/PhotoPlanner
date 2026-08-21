//
//  WeatherAlertFetcher.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.08.26.
//

import Foundation


@Observable
class WeatherAlertFetcher {
 
    var alerts      : [WeatherAlert] = []
    var isFetching  : Bool           = false
 
    private var lastFetchTime   : Date                 = .distantPast
    private let cacheMaxAge     : TimeInterval         = 300   // 5 minutes
    private let baseURL         : String               = "http://hansolo.eu:8081"
    private let expiryFormatter : ISO8601DateFormatter = {
        let f           = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
 
    // Fetches alerts for a coordinate, using cache if valid
    func fetchIfNeeded(latitude: Double, longitude: Double) async {
        // Return cached result if still fresh
        guard Date().timeIntervalSince(self.lastFetchTime) > self.cacheMaxAge else { return }
        await fetch(latitude: latitude, longitude: longitude)
    }
 
    func fetch(latitude: Double, longitude: Double) async {
        isFetching = true
 
        var components = URLComponents(string: "\(self.baseURL)/v2/alerts")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.6f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.6f", longitude))
        ]
 
        guard let url = components?.url else {
            isFetching = false
            return
        }
 
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else {
                isFetching = false
                return
            }
 
            let geoJSON  : AlertsGeoJSON = try JSONDecoder().decode(AlertsGeoJSON.self, from: data)
            let parsed   = geoJSON.features.compactMap { feature -> WeatherAlert? in
                guard let props = feature.properties else { return nil }
 
                let severity : AlertSeverity = AlertSeverity(rawValue: props.severity ?? "") ?? .unknown
 
                // Skip minor and unknown severities
                guard severity != .minor && severity != .unknown else { return nil }
 
                let expiry : Date? = props.expiry.flatMap {
                    expiryFormatter.date(from: $0) ??
                    ISO8601DateFormatter().date(from: $0)
                }
 
                // Skip already-expired alerts
                if let expiry, expiry < Date() { return nil }
 
                return WeatherAlert(id: props.id ?? UUID().uuidString, event: props.event    ?? "Weather Alert", headline: props.headline ?? props.event ?? "Weather Alert", severity: severity, expiry: expiry, sender: props.sender ?? "")
            }
            // Sort by severity — highest first
            .sorted { $0.severity < $1.severity }
 
            alerts        = parsed
            lastFetchTime = Date()
            isFetching    = false
 
        } catch {
            // Fail silently, show nothing if network/parsing fails
            isFetching    = false
        }
    }
}
