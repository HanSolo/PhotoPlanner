//
//  NowcastChecker.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 05.07.26.
//

import Foundation
import CoreLocation

 
struct NowcastConditions: Sendable {
    let hasThunderstormCell             : Bool
    let precipitationIntensityMmPerHour : Double   // 0 if none reported
    let cloudCoverPercent               : Double
    let visibilityKm                    : Double
    let conditionDescription            : String
    let fetchedAt                       : Date
}
 

private struct OWMResponse: Decodable {
 
    struct WeatherEntry: Decodable {
        let id          : Int
        let main        : String
        let description : String
    }
 
    struct Main: Decodable {
        let humidity : Int      // OWM returns integer percentage e.g. 92
    }
 
    struct Rain: Decodable {
        let oneHour : Double?
        enum CodingKeys: String, CodingKey { case oneHour = "1h" }
    }
 
    struct Clouds: Decodable {
        let all : Double
    }
 
    let weather    : [WeatherEntry]
    let main       : Main
    let visibility : Double?    // metres — not always present, default 10000
    let rain       : Rain?      // absent entirely when no rain
    let clouds     : Clouds
    let dt         : Int        // unix timestamp of measurement
}
 
 
actor NowcastChecker {
    // OWM condition code ranges
    private static let thunderstormRange : ClosedRange<Int> = 200...232
    private static let heavyRainCodes    : Set<Int>         = [502, 503, 504, 522, 531] // Heavy/violent rain codes within the 5xx rain group, 500 (light) and 501 (moderate) are intentionally excluded
 
    // Returns nil when outside the 2h nowcast window, or on any error, callers treat nil as "no override, use model forecast."
    func checkConditions(at coordinate : CLLocationCoordinate2D, for targetTime: Date) async -> NowcastConditions? {
        let hoursUntilTarget = targetTime.timeIntervalSince(Date()) / 3600
        guard abs(hoursUntilTarget) <= 2.0 else { return nil }
        guard let url = buildURL(coordinate: coordinate) else { return nil }
 
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200
            else { return nil }
 
            let decoded = try JSONDecoder().decode(OWMResponse.self, from: data)
            debugPrint("CrossChecked with OpenWeatherMap")
            return parse(decoded)
        } catch {
            return nil  // fail open
        }
    }
 
 
    private func buildURL(coordinate: CLLocationCoordinate2D) -> URL? {
        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")
        components?.queryItems = [
            URLQueryItem(name: "lat",   value: "\(coordinate.latitude)"),
            URLQueryItem(name: "lon",   value: "\(coordinate.longitude)"),
            URLQueryItem(name: "appid", value: "32cabca381ca632856caf5d3c7455abb"),
            URLQueryItem(name: "units", value: "metric")
        ]
        return components?.url
    }
 
    private func parse(_ response: OWMResponse) -> NowcastConditions {
        let primary        = response.weather.first
        let conditionId    = primary?.id ?? 0
 
        let isThunderstorm = Self.thunderstormRange.contains(conditionId)
        let isHeavyRain    = Self.heavyRainCodes.contains(conditionId)
 
        // rain.1h is absent entirely when there is no rain, default to 0
        let rainfallMm     = response.rain?.oneHour ?? 0
 
        // If the condition code says heavy rain but rain.1h is missing
        // (can happen with some stations), use a floor of 7.5mm/h as a
        // conservative estimate so the override still triggers correctly
        let effectiveRainfall = isHeavyRain && rainfallMm == 0 ? 7.5 : rainfallMm
 
        return NowcastConditions(hasThunderstormCell: isThunderstorm, precipitationIntensityMmPerHour: effectiveRainfall,
                                 cloudCoverPercent: response.clouds.all, visibilityKm: (response.visibility ?? 10000) / 1000.0,
                                 conditionDescription: primary?.description ?? "unknown", fetchedAt: Date(timeIntervalSince1970: TimeInterval(response.dt)))
    }
}
 
 
extension NowcastConditions {
 
    // Thunderstorm cells always override. Heavy rain (>5mm/h, roughly the boundary between moderate and heavy rain)
    // also overrides, washed-out light and reduced visibility make golden hour shooting impractical regardless of what
    // the model forecast says 35-70km away.
    var shouldOverridePrediction: Bool {
        hasThunderstormCell || precipitationIntensityMmPerHour > 5.0
    }
 
    var overrideReason: String {
        if hasThunderstormCell {
            return "Active thunderstorm at camera location (\(conditionDescription)), nowcast override"
        }
        return "Heavy rain at camera location: \(String(format: "%.1f", precipitationIntensityMmPerHour)) mm/h, nowcast override"
    }
}
