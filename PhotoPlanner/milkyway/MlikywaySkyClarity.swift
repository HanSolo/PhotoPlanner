//
//  MlikywaySkyClarity.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 17.06.26.
//

import Foundation
import SwiftUI
import WeatherKit
import CoreLocation


struct SkyClarityPoint {
    let time    : Date
    let clarity : Double   // 0 (overcast/hazy), 1 (crystal clear)
}


struct SkyClarityCalculator {

    // Approximate cloud fraction from the discrete WeatherKit condition,
    // since CachedHourlyWeather stores condition rather than raw cloudCover.
    static func approximateCloudFraction(conditionRawValue: String) -> Double {
        switch conditionRawValue {
            case "clear"                                           : return 0.0
            case "mostlyClear"                                     : return 0.15
            case "partlyCloudy"                                    : return 0.40
            case "mostlyCloudy"                                    : return 0.70
            case "cloudy"                                          : return 0.95
            case "foggy", "haze", "smoky", "blowingDust"           : return 0.85
            case "drizzle", "freezingDrizzle", "sunShowers"        : return 0.80
            case "rain", "heavyRain", "sleet", "freezingRain",
                 "wintryMix", "snow", "heavySnow", "flurries",
                 "sunFlurries", "blizzard", "blowingSnow", "hail"  : return 0.95
            case "isolatedThunderstorms", "scatteredThunderstorms",
                 "thunderstorms", "strongStorms"                   : return 0.95
            case "tropicalStorm", "hurricane"                      : return 1.0
            default                                                : return 0.5
        }
    }

    // Simplified clarity score with no directional dependency since stars just need a transparent, dark sky regardless of azimuth.
    static func clarity(cloudFraction: Double, humidity: Double, visibilityKm: Double) -> Double {
        let cloudScore      : Double = 1.0 - cloudFraction
        
        let humidityScore   : Double
        switch humidity {
            case ..<0.50     : humidityScore = 1.00
            case 0.50..<0.70 : humidityScore = 0.70
            case 0.70..<0.85 : humidityScore = 0.40
            default          : humidityScore = 0.15
        }

        let visibilityScore : Double = min(1.0, visibilityKm / 20.0)

        let composite       : Double = (cloudScore * 0.6) + (humidityScore * 0.2) + (visibilityScore * 0.2)
        return min(1.0, max(0.0, composite))
    }

    static func clarityColor(_ clarity: Double) -> Color {
        switch clarity {
            case 0.7...    : return .green
            case 0.4..<0.7 : return .yellow
            case 0.2..<0.4 : return .orange
            default        : return .red
        }
    }
}


@Observable
class MilkywaySkyClarityViewModel {
    var clarityPoints      : [SkyClarityPoint] = []
    var isLoadingWeather   : Bool              = false
    var weatherUnavailable : Bool              = false

    private let weatherService : WeatherService = WeatherService.shared

    // Loads clarity data, preferring the existing weather cache
    // over a fresh fetch when it's valid for this location/date.
    func loadClarity(at coordinate: CLLocationCoordinate2D, on date: Date, timeZone: TimeZone) {
        let location : CLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Try the existing weather overlay cache first
        if let cached = WeatherCacheStore.load(), cached.isValid(for: location, on: date) {
            clarityPoints = cached.hours.map { hour in
                let cloudFraction = SkyClarityCalculator.approximateCloudFraction(
                    conditionRawValue: hour.conditionRawValue
                )
                let clarity : Double = SkyClarityCalculator.clarity(cloudFraction: cloudFraction, humidity: hour.humidity, visibilityKm: hour.visibilityKm)
                return SkyClarityPoint(time: hour.date, clarity: clarity)
            }
            weatherUnavailable = false
            return
        }

        // Cache miss or stale -> fetch fresh, camera location only
        isLoadingWeather = true

        var calendar      : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay    : Date     = calendar.startOfDay(for: date)
        let endOfDay      : Date     = startOfDay.addingTimeInterval(86400)

        Task {
            do {
                let forecast = try await weatherService.weather(for: location, including: .hourly(startDate: startOfDay, endDate: endOfDay))
                let dayHours = forecast.forecast.filter { $0.date >= startOfDay && $0.date < endOfDay }

                let points = dayHours.map { hour -> SkyClarityPoint in
                    let clarity : Double = SkyClarityCalculator.clarity(cloudFraction: hour.cloudCover, humidity: hour.humidity, visibilityKm: hour.visibility.converted(to: .kilometers).value)
                    return SkyClarityPoint(time: hour.date, clarity: clarity)
                }

                await MainActor.run {
                    self.clarityPoints      = points
                    self.isLoadingWeather   = false
                    self.weatherUnavailable = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingWeather   = false
                    self.weatherUnavailable = true
                }
            }
        }
    }

    // Interpolated clarity at a specific time, for the current-time label.
    func clarity(at time: Date) -> Double? {
        guard !clarityPoints.isEmpty else { return nil }
        let timestamp : TimeInterval = time.timeIntervalSince1970
        guard let firstTime : TimeInterval = clarityPoints.first?.time.timeIntervalSince1970,
              let lastTime  : TimeInterval = clarityPoints.last?.time.timeIntervalSince1970
        else { return nil }

        if timestamp <= firstTime { return clarityPoints.first?.clarity }
        if timestamp >= lastTime  { return clarityPoints.last?.clarity  }

        var low = 0, high = clarityPoints.count - 1
        while low < high - 1 {
            let mid : Int = (low + high) / 2
            if clarityPoints[mid].time.timeIntervalSince1970 <= timestamp {
                low  = mid
            } else {
                high = mid
            }
        }

        let before   = clarityPoints[low]
        let after    = clarityPoints[high]
        let fraction = time.timeIntervalSince(before.time) / after.time.timeIntervalSince(before.time)
        return before.clarity + (after.clarity - before.clarity) * fraction
    }
}

struct SkyClarityBar: View {
    let clarityViewModel : MilkywaySkyClarityViewModel
    let startOfDay       : Date

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(0..<48) { segment in
                    let segmentTime = startOfDay.addingTimeInterval(Double(segment) * 1800)
                    let clarity     = clarityViewModel.clarity(at: segmentTime) ?? 0.5

                    Rectangle()
                        .fill(SkyClarityCalculator.clarityColor(clarity).opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 4)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .frame(height: 4)
    }
}


struct SkyClarityHint: View {
    let clarityViewModel   : MilkywaySkyClarityViewModel
    let selectedTime       : Date
    let isInDarknessWindow : Bool

    
    var body: some View {
        if clarityViewModel.weatherUnavailable {
            hintPill(
                text:  "Weather unavailable",
                icon:  "exclamationmark.triangle",
                color: .white.opacity(0.5)
            )
        } else if let clarity = clarityViewModel.clarity(at: selectedTime),
                  isInDarknessWindow,
                  clarity < 0.4 {
            hintPill(
                text:  "Cloudy skies — Milky Way may not be visible",
                icon:  "cloud.fill",
                color: .orange
            )
        }
    }

    private func hintPill(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.6))
        .clipShape(Capsule())
    }
}
