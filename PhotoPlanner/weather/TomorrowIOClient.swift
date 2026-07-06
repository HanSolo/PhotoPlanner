//
//  TomorrowIOClient.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 06.07.26.
//

import Foundation
import CoreLocation

 
struct TomorrowIOHourlyConditions: Sendable {
    let time          : Date
    let cloudBaseKm   : Double?   // nil when sky is clear / no cloud base reported
    let cloudCoverPct : Double    // 0...100
    let visibilityKm  : Double
}
 
 
private struct TomorrowIOResponse: Decodable {
    struct Timelines: Decodable {
        let hourly: [HourlyEntry]
    }
    struct HourlyEntry: Decodable {
        let time   : String
        let values : HourlyValues
    }
    struct HourlyValues: Decodable {
        let cloudBase  : Double?   // km, null when no clouds
        let cloudCover : Double    // 0...100 percentage
        let visibility : Double?   // [km]
    }
 
    let timelines: Timelines
}
 
 
actor TomorrowIOCallTracker {
    private var callTimestamps: [Date] = []
 
    // Returns true if a call is allowed within the hourly budget
    func canMakeCall(hourlyLimit: Int = 20) -> Bool {
        let now        = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        callTimestamps = callTimestamps.filter { $0 > oneHourAgo }
        return callTimestamps.count < hourlyLimit
    }
 
    func recordCall() {
        callTimestamps.append(Date())
    }
}
 
 
actor TomorrowIOClient {
    
    private let callTracker : TomorrowIOCallTracker = TomorrowIOCallTracker()
    private let session     : URLSession            = URLSession.shared
 
    // Simple in memory cache, skip refetch if same location and data is less than 1 hour old
    private var cachedCoordinate : CLLocationCoordinate2D?
    private var cachedAt         : Date?
    private var cachedHours      : [TomorrowIOHourlyConditions] = []
 
 
    // Returns hourly cloud conditions for the given date at the camera location, or nil if rate limited / unavailable.
    func hourlyConditions(at coordinate: CLLocationCoordinate2D, on date: Date) async -> [TomorrowIOHourlyConditions]? {
        // Return cached data if still valid
        if let cached = cachedCoordinate, let cachedTime = cachedAt {
            let sameLocation = abs(cached.latitude  - coordinate.latitude)  < 0.01 && abs(cached.longitude - coordinate.longitude) < 0.01
            let fresh        = Date().timeIntervalSince(cachedTime) < 3600
            if sameLocation && fresh && !cachedHours.isEmpty {
                return cachedHours
            }
        }
 
        // Check hourly rate limit before making a call
        guard await callTracker.canMakeCall() else {
            return nil
        }
 
        guard let url = buildURL(coordinate: coordinate, date: date) else { return nil }
 
        do {
            await callTracker.recordCall()
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return nil }
 
            let decoded = try JSONDecoder().decode(TomorrowIOResponse.self, from: data)
            let hours   = parse(decoded)
 
            // Cache results
            cachedCoordinate = coordinate
            cachedAt         = Date()
            cachedHours      = hours
 
            return hours
        } catch {
            return nil  // fail open, never block prediction
        }
    }
 
    // Returns the single hourly entry closest to the given time, or nil if no data is available
    func conditions(at coordinate: CLLocationCoordinate2D, time: Date) async -> TomorrowIOHourlyConditions? {
        guard let hours = await hourlyConditions(at: coordinate, on: time) else {
            return nil
        }
        return hours.min(by: {
            abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time))
        })
    }
 
    
    private func buildURL(coordinate: CLLocationCoordinate2D, date: Date) -> URL? {
        // Tomorrow.io Timeline endpoint, hourly timestep
        // Fields: cloudBase, cloudCover, visibility
        var components = URLComponents(string: "https://api.tomorrow.io/v4/timelines")
        components?.queryItems = [
            URLQueryItem(name: "location",  value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "fields",    value: "cloudBase,cloudCover,visibility"),
            URLQueryItem(name: "timesteps", value: "1h"),
            URLQueryItem(name: "units",     value: "metric"),
            URLQueryItem(name: "apikey",    value: "qxRFfzCHzB4h9nG09so75APTQtp1LQpS")
        ]
        return components?.url
    }
 
    private func parse(_ response: TomorrowIOResponse) -> [TomorrowIOHourlyConditions] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
 
        return response.timelines.hourly.compactMap { entry in
            // Try with fractional seconds first, fall back without
            let time = formatter.date(from: entry.time) ?? ISO8601DateFormatter().date(from: entry.time)
            guard let time else { return nil }
 
            return TomorrowIOHourlyConditions(time: time, cloudBaseKm: entry.values.cloudBase, cloudCoverPct: entry.values.cloudCover, visibilityKm: entry.values.visibility ?? 16.0)
        }
    }
}


extension TomorrowIOHourlyConditions {
 
    // Cloud base in metres (converted from km).
    var cloudBaseMeters: Double? {
        cloudBaseKm.map { $0 * 1000 }
    }
 
    // Returns true if the cloud base height is in the range where a solid overcast layer can be illuminated from below at golden hour:
    // < 150m    : fog/very low stratus, sun can't get under it
    // > 2500m   : too high, light dissipates before reaching the base
    // 150–2500m : the "sweet spot" for cloud canvas illumination
    var isCloudBaseInCanvasRange: Bool {
        guard let baseM = cloudBaseMeters else {
            // nil means no clouds reported, not a canvas condition
            return false
        }
        return baseM >= 150 && baseM <= 2500
    }
}
