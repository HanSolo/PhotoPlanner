//
//  SunriseSunsetPredictor.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation
import WeatherKit
import CoreLocation
import MapKit


actor SunriseSunsetPredictor {

    private let weatherService : WeatherService = WeatherService.shared


    func dailyTimeline(at location: CLLocationCoordinate2D, on date: Date, shootAzimuth: Double, sunPos: SunPos) async throws -> DailyQualityTimeline {
        let timeZone   = try await fetchTimeZone(for: location) ?? .current
        var calendar   = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay   = startOfDay.addingTimeInterval(86400)
        
        // Request hourly forecast for the specific date range
        let hourlyForecast = try await weatherService.weather(for: CLLocation(latitude: location.latitude, longitude: location.longitude), including: .hourly(startDate: startOfDay, endDate: endOfDay))

        let dayHours = hourlyForecast.forecast.filter {
            $0.date >= startOfDay && $0.date < endOfDay
        }

        guard !dayHours.isEmpty else { throw PredictionError.noForecastData }

        let slots: [DailyQualityTimeline.HourSlot] = dayHours.map { hour in
            let sunPos      = calcSunPos(at: location, time: hour.date)
            let directional = directionalInfo(sunAzimuth:   sunPos.azimuth,
                                              shootAzimuth: shootAzimuth)
            let localWindow = hourlyForecast.forecast.filter {
                abs($0.date.timeIntervalSince(hour.date)) <= 3600
            }
            let isSunUp = sunPos.altitude > -6

            let score: SunriseSunsetScore? = isSunUp ? self.score(window: localWindow, primary: hour, event: SolarEvent(time: hour.date, type: .goldenHour), directional: directional) : nil

            return DailyQualityTimeline.HourSlot(time: hour.date, score: score, sunAltitude: sunPos.altitude, sunAzimuth: sunPos.azimuth, isSunUp: isSunUp)
        }

        let solarNoon   = solarNoonTime(at: location, startOfDay: startOfDay)
        let bestSunrise = slots.filter { $0.time < solarNoon && $0.isSunUp && $0.score != nil }.max { gradeValue($0.score!.overall) < gradeValue($1.score!.overall) }
        let bestSunset  = slots.filter { $0.time >= solarNoon && $0.isSunUp && $0.score != nil }.max { gradeValue($0.score!.overall) < gradeValue($1.score!.overall) }

        return DailyQualityTimeline(date: date, slots: slots, bestSunrise: bestSunrise, bestSunset: bestSunset, timeZone: timeZone)
    }
        
    func directionalInfo(sunAzimuth: Double, shootAzimuth: Double) -> DirectionalCloudInfo {
        var diff = (shootAzimuth - sunAzimuth).truncatingRemainder(dividingBy: 360)
        if diff >  180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        let absDiff = abs(diff)

        return DirectionalCloudInfo(sunAzimuth: sunAzimuth, shootAzimuth: shootAzimuth, angularDifference: absDiff, shootingTowardSun: absDiff < 45, shootingAwaySun: absDiff > 135)
    }

    func score(window: [HourWeather], primary: HourWeather, event: SolarEvent, directional: DirectionalCloudInfo) -> SunriseSunsetScore {
        var reasons: [String] = []

        // -- Directional context --
        switch directional.angularDifference {
            case ..<45:
                reasons.append("Shooting toward sun — backlit, lens flare risk")
            case 45..<90:
                reasons.append("Sun at \(Int(directional.angularDifference))° — strong sidelight")
            case 90..<135:
                reasons.append("Sun at \(Int(directional.angularDifference))° — soft sidelight")
            default:
                reasons.append("Shooting away from sun — reflected colour on clouds")
        }

        // -- Cloud score — varies by shooting direction --
        let cloud = primary.cloudCover   // 0.0–1.0
        let cloudScore: Double

        if directional.shootingTowardSun {
            // Into the sun: some backlit cloud is spectacular;
            // solid overcast on the horizon blocks everything
            switch cloud {
                case ..<0.1:
                    cloudScore = 0.6
                    reasons.append("Clear sky toward sun — clean light, limited colour")
                case 0.1..<0.4:
                    cloudScore = 1.0
                    reasons.append("Scattered cloud toward sun — backlit drama likely")
                case 0.4..<0.65:
                    cloudScore = 0.8
                    reasons.append("Broken cloud toward sun — strong colour likely")
                case 0.65..<0.85:
                    cloudScore = 0.4
                    reasons.append("Heavy cloud toward sun — may block colour burst")
                default:
                    cloudScore = 0.1
                    reasons.append("Solid overcast toward sun — colour burst blocked")
            }
        } else if directional.shootingAwaySun {
            // Away from sun: needs clouds ahead to catch reflected colour;
            // clear sky gives nothing to paint
            switch cloud {
                case ..<0.15:
                    cloudScore = 0.3
                    reasons.append("Clear sky ahead — little to reflect colour onto")
                case 0.15..<0.5:
                    cloudScore = 0.9
                    reasons.append("Clouds ahead will catch reflected colour")
                case 0.5..<0.75:
                    cloudScore = 1.0
                    reasons.append("Good cloud canvas ahead for reflected colour")
                case 0.75..<0.90:
                    cloudScore = 0.6
                    reasons.append("Heavy cloud ahead — colour may be muted")
                default:
                    cloudScore = 0.2
                    reasons.append("Solid overcast ahead — flat light likely")
            }

        } else {
            // Sidelight (45–135°): standard scoring
            switch cloud {
            case ..<0.1     : cloudScore = 0.5
            case 0.1..<0.3  : cloudScore = 0.8
            case 0.3..<0.5  : cloudScore = 1.0
            case 0.5..<0.7  : cloudScore = 0.9
            case 0.7..<0.85 : cloudScore = 0.5
            default         : cloudScore = 0.1
            }
        }

        // -- Low cloud base proxy --
        // High cloud cover + poor visibility → colour burst likely above clouds
        let visibilityKm  = primary.visibility.converted(to: .kilometers).value
        let likelyLowCloud = cloud > 0.6 && visibilityKm < 8
        if likelyLowCloud && directional.shootingTowardSun {
            reasons.append("Low cloud base likely — colour burst may be above clouds")
        }

        // -- Humidity score --
        let humidity = primary.humidity
        let humidityScore: Double
        switch humidity {
            case ..<0.4:
                humidityScore = 1.0
                reasons.append("Low humidity — crisp colours expected")
            case 0.4..<0.6:
                humidityScore = 0.8
            case 0.6..<0.75:
                humidityScore = 0.6
                reasons.append("Moderate humidity — some haze likely")
            default:
                humidityScore = 0.3
                reasons.append("High humidity — hazy colours likely")
        }

        // -- Visibility score --
        let visibilityScore: Double
        switch visibilityKm {
            case 20...:   visibilityScore = 1.0
            case 10..<20: visibilityScore = 0.8
            case 5..<10:
                visibilityScore = 0.5
                reasons.append("Reduced visibility — haze or mist present")
            default:
                visibilityScore = 0.1
                reasons.append("Poor visibility — fog or heavy haze")
        }

        // -- Precipitation penalty --
        let isRainy = window.contains { $0.precipitationChance > 0.4 }
        if isRainy { reasons.append("Rain likely — colours will be obscured") }

        // -- Wind bonus (clears atmosphere) --
        let windKph   = primary.wind.speed.converted(to: .kilometersPerHour).value
        let windBonus: Double = windKph > 20 ? 0.05 : 0.0
        if windBonus > 0 { reasons.append("Breezy — atmosphere likely clear") }

        // -- Weighted composite --
        var composite = (cloudScore      * 0.50) + (humidityScore   * 0.25) + (visibilityScore * 0.20) + windBonus

        if isRainy        { composite *= 0.4 }
        if likelyLowCloud { composite *= 0.7 }
        composite = min(1.0, max(0.0, composite))

        let grade: SunriseSunsetScore.Grade
        switch composite {
            case ..<0.25     : grade = .poor
            case 0.25..<0.45 : grade = .fair
            case 0.45..<0.65 : grade = .good
            case 0.65..<0.82 : grade = .great
            default          : grade = .spectacular
        }

        return SunriseSunsetScore(overall: grade, cloudScore: cloudScore, humidityScore: humidityScore, visibilityScore: visibilityScore, reasoning: reasons)
    }    
    
    private func solarNoonTime(at coordinate: CLLocationCoordinate2D, startOfDay: Date) -> Date {
        var bestTime     = startOfDay.addingTimeInterval(12 * 3600)
        var bestAltitude = -90.0

        for minutes in stride(from: 0.0, through: 86400, by: 600) {
            let time     = startOfDay.addingTimeInterval(minutes)
            let altitude = calcSunPos(at: coordinate, time: time).altitude
            if altitude > bestAltitude {
                bestAltitude = altitude
                bestTime     = time
            }
        }
        return bestTime
    }
    
    private func calcSunPos(at coordinate: CLLocationCoordinate2D, time: Date) -> SunPos {
        let jd         = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let n          = jd - 2451545.0

        let L          = (280.46 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let g          = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360)
        let gRad       = g * .pi / 180
        let lambda     = L + 1.915 * sin(gRad) + 0.020 * sin(2 * gRad)

        let epsilon    = 23.439 - 0.0000004 * n
        let epsilonRad = epsilon * .pi / 180
        let lambdaRad  = lambda  * .pi / 180

        let sinDec     = sin(epsilonRad) * sin(lambdaRad)
        let dec        = asin(sinDec)
        let ra         = atan2(cos(epsilonRad) * sin(lambdaRad), cos(lambdaRad))

        let c          = Calendar(identifier: .gregorian).dateComponents([.hour, .minute, .second], from: time)
        let utH        = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600

        let gmst       = (6.697375 + 0.0657098242 * n + utH).truncatingRemainder(dividingBy: 24)
        let lha        = (gmst * 15 + coordinate.longitude - ra * 180 / .pi).truncatingRemainder(dividingBy: 360)
        let lhaRad     = lha * .pi / 180
        let latRad     = coordinate.latitude * .pi / 180

        let sinAlt     = sin(latRad) * sin(dec) + cos(latRad) * cos(dec) * cos(lhaRad)
        let altitude   = asin(sinAlt) * 180 / .pi

        let cosAz      = (sin(dec) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(sinAlt)))
        var azimuth    = acos(max(-1, min(1, cosAz))) * 180 / .pi
        if sin(lhaRad) > 0 { azimuth = 360 - azimuth }

        return SunPos(altitude: altitude, azimuth: azimuth)
    }
    
    private func fetchTimeZone(for location: CLLocationCoordinate2D) async throws -> TimeZone? {
        let request  = MKReverseGeocodingRequest(location: CLLocation(latitude: location.latitude, longitude: location.longitude))
        return try await request?.mapItems.first?.timeZone
    }
    
    private func gradeValue(_ grade: SunriseSunsetScore.Grade) -> Int {
        switch grade {
            case .poor        : return 0
            case .fair        : return 1
            case .good        : return 2
            case .great       : return 3
            case .spectacular : return 4
        }
    }
}
