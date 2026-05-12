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


    func getDailyTimeline(at location: CLLocationCoordinate2D, on date: Date, shootAzimuth: Double, sunPos: SunPos) async throws -> DailyQualityTimeline {
        let timeZone   = try await Helper.fetchTimeZone(for: location) ?? .current
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
            let directional = getDirectionalInfo(sunAzimuth:   sunPos.azimuth, shootAzimuth: shootAzimuth)
            let localWindow = hourlyForecast.forecast.filter {
                abs($0.date.timeIntervalSince(hour.date)) <= 3600
            }
            let isSunUp : Bool                = sunPos.altitude > -6
            let score   : SunriseSunsetScore? = isSunUp ? self.calcScore(window: localWindow, primary: hour, event: SolarEvent(time: hour.date, type: .goldenHour), directional: directional) : nil

            return DailyQualityTimeline.HourSlot(time: hour.date, score: score, sunAltitude: sunPos.altitude, sunAzimuth: sunPos.azimuth, isSunUp: isSunUp)
        }

        let solarNoon   = getSolarNoonTime(at: location, startOfDay: startOfDay)
        let bestSunrise = slots.filter { $0.time < solarNoon && $0.isSunUp && $0.score != nil }.max { gradeValue($0.score!.overall) < gradeValue($1.score!.overall) }
        let bestSunset  = slots.filter { $0.time >= solarNoon && $0.isSunUp && $0.score != nil }.max { gradeValue($0.score!.overall) < gradeValue($1.score!.overall) }

        return DailyQualityTimeline(date: date, slots: slots, bestSunrise: bestSunrise, bestSunset: bestSunset, timeZone: timeZone)
    }
        
    func getDirectionalInfo(sunAzimuth: Double, shootAzimuth: Double) -> DirectionalCloudInfo {
        var diff = (shootAzimuth - sunAzimuth).truncatingRemainder(dividingBy: 360)
        if diff >  180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        let absDiff = abs(diff)

        return DirectionalCloudInfo(sunAzimuth: sunAzimuth, shootAzimuth: shootAzimuth, angularDifference: absDiff, shootingTowardSun: absDiff < 45, shootingAwaySun: absDiff > 135)
    }

    func calcScore(window: [HourWeather], primary: HourWeather, event: SolarEvent, directional: DirectionalCloudInfo) -> SunriseSunsetScore {
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
        let cloud     : Double = primary.cloudCover   // 0.0–1.0
        let cloudScore: Double

        if directional.shootingTowardSun {
            switch cloud {
                case ..<0.1:
                    cloudScore = 0.5
                    reasons.append("Clear sky toward sun — clean but limited colour")
                case 0.1..<0.25:
                    cloudScore = 0.85
                    reasons.append("Light cloud toward sun — good colour potential")
                case 0.25..<0.45:
                    cloudScore = 1.0
                    reasons.append("Scattered cloud toward sun — backlit drama likely")
                case 0.45..<0.60:
                    cloudScore = 0.7
                    reasons.append("Broken cloud toward sun — colour possible")
                case 0.60..<0.80:
                    cloudScore = 0.3
                    reasons.append("Heavy cloud toward sun — colour burst likely blocked")
                default:
                    cloudScore = 0.05
                    reasons.append("Solid overcast toward sun — colour burst blocked")
            }

        } else if directional.shootingAwaySun {
            switch cloud {
                case ..<0.15:
                    cloudScore = 0.25
                    reasons.append("Clear sky ahead — nothing to reflect colour onto")
                case 0.15..<0.40:
                    cloudScore = 0.85
                    reasons.append("Clouds ahead will catch reflected colour")
                case 0.40..<0.65:
                    cloudScore = 1.0
                    reasons.append("Good cloud canvas ahead for reflected colour")
                case 0.65..<0.85:
                    cloudScore = 0.45
                    reasons.append("Heavy cloud ahead — colour may be muted")
                default:
                    cloudScore = 0.1
                    reasons.append("Solid overcast ahead — flat light likely")
            }

        } else {
            // Sidelight
            switch cloud {
                case ..<0.1     : cloudScore = 0.45
                case 0.1..<0.3  : cloudScore = 0.75
                case 0.3..<0.5  : cloudScore = 0.95
                case 0.5..<0.7  : cloudScore = 0.7
                case 0.7..<0.85 : cloudScore = 0.3
                default:          cloudScore = 0.05
            }
        }

        // Tighten humidity — maritime/coastal locations penalised more
        let humidity      : Double = primary.humidity
        let humidityScore : Double
        switch humidity {
            case ..<0.35:
                humidityScore = 1.0
                reasons.append("Low humidity — crisp colours expected")
            case 0.35..<0.50:
                humidityScore = 0.8
            case 0.50..<0.65:
                humidityScore = 0.55
                reasons.append("Moderate humidity — some haze likely")
            case 0.65..<0.80:
                humidityScore = 0.3
                reasons.append("High humidity — hazy colours likely")
            default:
                humidityScore = 0.1
                reasons.append("Very high humidity — significant haze expected")
        }
        
        let humidityCap: Double
        switch humidity {
            case ..<0.50     : humidityCap = 1.00   // no cap
            case 0.50..<0.65 : humidityCap = 0.80   // max "Great"
            case 0.65..<0.75 : humidityCap = 0.64   // max "Good"
            case 0.75..<0.85 : humidityCap = 0.48   // max "Fair"
            default:           humidityCap = 0.30   // max "Poor" — very humid, colours washed out
        }
        
        let conditionPenalty: Double
        switch primary.condition {

            // Clear — full potential
            case .clear, .mostlyClear:
                conditionPenalty = 1.0

            // Partial cloud — good potential
            case .partlyCloudy:
                conditionPenalty = 0.95

            // Mostly cloudy — reduced
            case .mostlyCloudy:
                conditionPenalty = 0.6

            // Full overcast — flat light
            case .cloudy:
                conditionPenalty = 0.35

            // Atmospheric — haze kills colour
            case .haze:
                conditionPenalty = 0.4
            case .smoky:
                conditionPenalty = 0.3
            case .blowingDust:
                conditionPenalty = 0.2
            case .foggy:
                conditionPenalty = 0.1

            // Temperature extremes — not directly relevant to colour
            // but often associated with haze or poor visibility
            case .hot:
                conditionPenalty = 0.7
            case .frigid:
                conditionPenalty = 0.8   // cold clear air is often very crisp

            // Light precipitation — can still produce colour
            case .drizzle, .freezingDrizzle, .sunShowers:
                conditionPenalty = 0.7 // it was 0.4, moved to 0.7 - 0.8 might be better
            case .sunFlurries:
                conditionPenalty = 0.5   // snow flurries with sun can be beautiful

            // Moderate precipitation
            case .rain, .sleet, .flurries:
                conditionPenalty = 0.2
            case .wintryMix, .freezingRain:
                conditionPenalty = 0.15

            // Heavy precipitation
            case .heavyRain, .snow, .hail:
                conditionPenalty = 0.05
            case .heavySnow, .blowingSnow:
                conditionPenalty = 0.05
            case .blizzard:
                conditionPenalty = 0.02

            // Storms
            case .isolatedThunderstorms, .scatteredThunderstorms:
                conditionPenalty = 0.15
            case .strongStorms, .thunderstorms:
                conditionPenalty = 0.05

            // Tropical hazards
            case .tropicalStorm:
                conditionPenalty = 0.05
            case .hurricane:
                conditionPenalty = 0.02
            default :
                conditionPenalty = 1.0
        }

        // Visibility — weight bad visibility more harshly
        let visibilityKm    : Double = primary.visibility.converted(to: .kilometers).value
        let visibilityScore : Double
        switch visibilityKm {
            case 25...:   visibilityScore = 1.0
            case 15..<25: visibilityScore = 0.8
            case 10..<15: visibilityScore = 0.6
            case 5..<10:
                visibilityScore = 0.3
                reasons.append("Reduced visibility — haze or mist present")
            default:
                visibilityScore = 0.05
                reasons.append("Poor visibility — fog or heavy haze")
        }

        // Low cloud base proxy — tighter threshold
        let likelyLowCloud = cloud > 0.5 && visibilityKm < 10
        if likelyLowCloud && directional.shootingTowardSun {
            reasons.append("Low cloud base likely — colour burst may be above clouds")
        }

        // Rebalanced weights — humidity and visibility penalise more
        var composite = (cloudScore      * 0.45)
                      + (humidityScore   * 0.30)
                      + (visibilityScore * 0.25)

        let isRainy : Bool = window.contains { $0.precipitationChance > 0.4 }
        
        if isRainy        { composite *= 0.3 }
        if likelyLowCloud { composite *= 0.6 }

        // Wind bonus only if also low humidity — breezy + humid isn't better
        let windKph : Double = primary.wind.speed.converted(to: .kilometersPerHour).value
        if windKph > 20 && humidity < 0.6 {
            composite += 0.05
            reasons.append("Breezy and dry — atmosphere likely clear")
        }

        // Apply condition as a multiplier
        composite *= conditionPenalty

        // Apply humidity as a hard cap — this is the key change
        composite = min(composite, humidityCap)
        composite = min(1.0, max(0.0, composite))

        // Raise the bar for top grades
        let grade: SunriseSunsetScore.Grade
        switch composite {
            case ..<0.30     : grade = .poor
            case 0.30..<0.48 : grade = .fair
            case 0.48..<0.64 : grade = .good
            case 0.64..<0.80 : grade = .great
            default:           grade = .grand
        }
        return SunriseSunsetScore(overall: grade, cloudScore: cloudScore, humidityScore: humidityScore, visibilityScore: visibilityScore, reasoning: reasons)
    }    
    
    private func getSolarNoonTime(at coordinate: CLLocationCoordinate2D, startOfDay: Date) -> Date {
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
        
    private func gradeValue(_ grade: SunriseSunsetScore.Grade) -> Int {
        switch grade {
            case .poor        : return 0
            case .fair        : return 1
            case .good        : return 2
            case .great       : return 3
            case .grand : return 4
        }
    }
}
