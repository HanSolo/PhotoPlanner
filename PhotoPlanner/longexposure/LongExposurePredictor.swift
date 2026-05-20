//
//  LongExposurePredictor.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.05.26.
//

import Foundation
import CoreLocation
import WeatherKit


actor LongExposurePredictor {
    private let weatherService = WeatherService.shared

    
    func dailyTimeline(at location: CLLocationCoordinate2D, on date: Date, cameraHeading: Double) async throws -> LongExposureDailyTimeline {
        let timeZone : TimeZone = await Helper.fetchTimeZone(for: location)
        var calendar : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfDay : Date = calendar.startOfDay(for: date)
        let endOfDay   : Date = startOfDay.addingTimeInterval(86400)

        let hourlyForecast = try await weatherService.weather(for: CLLocation(latitude: location.latitude, longitude: location.longitude), including: .hourly(startDate: startOfDay, endDate: endOfDay))
        let dayHours       : [HourWeather] = hourlyForecast.forecast.filter { $0.date >= startOfDay && $0.date < endOfDay }

        guard !dayHours.isEmpty else { throw PredictionError.noForecastData }

        let slots: [LongExposureDailyTimeline.HourSlot] = dayHours.map { hour in
            let sunPosition : SunPos = calcSunPos(at: location, time: hour.date)
            let isSunUp     : Bool   = sunPosition.altitude > 0

            let conditions: LongExposureConditions? = isSunUp
                ? scoreConditions(
                    hour: hour,
                    cameraHeading: cameraHeading,
                    sunAzimuth: sunPosition.azimuth,
                    sunAltitude: sunPosition.altitude,
                    localWindow: hourlyForecast.forecast.filter { abs($0.date.timeIntervalSince(hour.date)) <= 3600 }
                )
                : nil

            return LongExposureDailyTimeline.HourSlot(time: hour.date, conditions: conditions, isSunUp: isSunUp)
        }

        let bestSlot : LongExposureDailyTimeline.HourSlot? = slots.filter { $0.conditions != nil }.max { gradeValue($0.conditions!.overall) < gradeValue($1.conditions!.overall) }

        return LongExposureDailyTimeline(date: date, slots: slots, bestSlot: bestSlot, timeZone: timeZone)
    }

    
    private func scoreConditions(hour: HourWeather, cameraHeading: Double, sunAzimuth: Double, sunAltitude: Double, localWindow: [HourWeather]) -> LongExposureConditions {
        var reasoning: [String] = []
        
        let cloudCoverage    : Double = hour.cloudCover
        let conditionPenalty : Double
        
        // Use WeatherCondition as a proxy for cloud texture.
        // Cloudy = uniform flat grey = no texture.
        // MostlyCloudy/PartlyCloudy = more likely to have texture.
        switch hour.condition {
            case .cloudy:
                // Uniform overcast — the article says this needs visible texture to work.
                // Penalise heavily since WeatherKit reporting .cloudy means flat grey sky.
                conditionPenalty = 0.3
            case .mostlyCloudy:
                conditionPenalty = 0.8   // likely some texture variation
            case .partlyCloudy:
                conditionPenalty = 1.0   // best — mixed bright and dark areas
            case .mostlyClear, .clear:
                conditionPenalty = 0.2   // too little cloud
            default:
                conditionPenalty = 0.5
        }

        let cloudScore : Double
        switch cloudCoverage {
            case ..<0.20:
                cloudScore = 0.0
                reasoning.append("Too little cloud cover — no movement effect possible")
            case 0.20..<0.40:
                cloudScore = 0.3
                reasoning.append("Below 50% cloud cover — limited movement effect")
            case 0.40..<0.60:
                cloudScore = 0.8
                reasoning.append("Partly cloudy — good cloud texture and coverage")
            case 0.60..<0.80:
                cloudScore = 1.0
                reasoning.append("More than 60% cloud cover — ideal for long exposure")
            case 0.80..<0.95:
                cloudScore = 0.6   // reduced from 0.85 — needs texture to work
                reasoning.append("Heavy cloud cover — only good if clouds show visible texture")
            default:
                cloudScore = 0.25  // reduced from 0.5 — uniform overcast is usually flat
                reasoning.append("Near 100% overcast — likely flat grey, little photographic interest")
        }
        
        // Apply condition as texture proxy
        let textureAdjustedCloudScore : Double = cloudScore * conditionPenalty

        
        let windSpeedKph        : Double = hour.wind.speed.converted(to: .kilometersPerHour).value
        let beaufortValue       : Int    = kphToBeaufort(windSpeedKph)
        let windScore           : Double
        let recommendedExposure : LongExposureConditions.RecommendedExposure

        switch beaufortValue {
            case ..<2:
                windScore           = 0.0   // was 0.1 — effectively zero, don't suggest it
                recommendedExposure = .tooCalm
                reasoning.append("Wind too calm — clouds stationary, long exposure effect not possible")
            case 2..<3:
                windScore           = 0.3   // was 0.5 — reduced, marginal conditions
                recommendedExposure = .long
                reasoning.append("Light wind (\(beaufortValue) Bft) — very slow movement, marginal conditions")
            case 3..<4:
                windScore           = 0.65  // new intermediate step
                recommendedExposure = .short
                reasoning.append("Moderate wind (\(beaufortValue) Bft) — acceptable cloud movement, ~30 sec exposure")
            case 4..<5:
                windScore           = 0.85
                recommendedExposure = .short
                reasoning.append("Good wind (\(beaufortValue) Bft) — good cloud movement, ~30 sec exposure")
            case 5..<7:
                windScore           = 1.0
                recommendedExposure = .veryShort
                reasoning.append("Strong wind (\(beaufortValue) Bft) — excellent movement, ~15 sec exposure")
            default:
                windScore           = 0.7
                recommendedExposure = .veryShort
                reasoning.append("Very strong wind (\(beaufortValue) Bft) — good movement but tripod stability risk")
        }

        
        var sunAngleDifference : Double = abs(cameraHeading - sunAzimuth).truncatingRemainder(dividingBy: 360)
        if sunAngleDifference > 180 { sunAngleDifference = 360 - sunAngleDifference }

        let sunAngleScore : Double
        switch sunAngleDifference {
            case ..<20:
                // Shooting directly into sun — only acceptable when heavily overcast
                let sunHiddenByCloud = cloudCoverage > 0.85
                sunAngleScore = sunHiddenByCloud ? 0.5 : 0.1
                if sunHiddenByCloud {
                    reasoning.append("Shooting toward sun but heavy clouds cover it — acceptable")
                } else {
                    reasoning.append("Shooting into sun — extreme contrast, flare and filter artefacts, avoid")
                }
            case 20..<45:
                sunAngleScore = 0.4
                reasoning.append("Sun nearly in front — high contrast and flare risk")
            case 45..<90:
                sunAngleScore = 0.85
                reasoning.append("Sun at \(Int(sunAngleDifference))° — good angle, strong sidelight texture")
            case 90..<135:
                sunAngleScore = 1.0
                reasoning.append("Sun at \(Int(sunAngleDifference))° — excellent angle for maximum texture")
            case 135..<160:
                sunAngleScore = 0.9
                reasoning.append("Sun mostly behind — good backlit cloud effect possible")
            default:
                // Sun directly behind — article says cloud effect compensates for flat lighting
                sunAngleScore = 0.8
                reasoning.append("Sun in back — cloud movement effect compensates for flat lighting")
        }


        let windDirectionDegrees : Double = hour.wind.direction.converted(to: .degrees).value
        var windHeadingAngle     : Double = abs(cameraHeading - windDirectionDegrees).truncatingRemainder(dividingBy: 360)
        if windHeadingAngle > 180 { windHeadingAngle = 360 - windHeadingAngle }

        let windCloudAlignment : LongExposureConditions.WindCloudAlignment        
        switch windHeadingAngle {
            case ..<30     : windCloudAlignment = .parallel
            case 30..<60   : windCloudAlignment = .diagonal
            case 60..<120  : windCloudAlignment = .perpendicular
            case 120..<150 : windCloudAlignment = .diagonal
            default        : windCloudAlignment = .parallel
        }
        reasoning.append(windCloudAlignment.effectDescription)

        
        let recentPrecipitation   : Bool   = localWindow.contains { $0.precipitationChance > 0.4 }
        let isPostFrontalClearing : Bool   = cloudCoverage < 0.75 && recentPrecipitation
        var transitionBonus       : Double = 0.0
        if isPostFrontalClearing {
            transitionBonus = 0.15
            reasoning.append("Post-frontal clearing — prime long exposure opportunity")
        }

        
        let isActivelyRaining : Bool = hour.precipitationChance > 0.6
        if isActivelyRaining {
            reasoning.append("Active precipitation likely — shooting impractical")
        }

        var composite = (textureAdjustedCloudScore * 0.40) + (windScore * 0.40) + (sunAngleScore * 0.20)

        if isActivelyRaining { composite *= 0.2 }
        composite += transitionBonus
        composite  = min(1.0, max(0.0, composite))
                
        let grade : LongExposureConditions.Grade
        switch composite {
            case ..<0.35     : grade = .poor
            case 0.35..<0.52 : grade = .fair
            case 0.52..<0.68 : grade = .good
            case 0.68..<0.83 : grade = .great
            default          : grade = .grand
        }

        return LongExposureConditions(overall: grade, cloudScore: cloudScore, windScore: windScore,
                                      sunAngleScore: sunAngleScore, windCloudAlignment: windCloudAlignment,
                                      recommendedExposure: recommendedExposure, reasoning: reasoning
        )
    }
    

    private func gradeValue(_ grade: LongExposureConditions.Grade) -> Int {
        switch grade {
            case .poor  : return 0
            case .fair  : return 1
            case .good  : return 2
            case .great : return 3
            case .grand : return 4
        }
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
    
    private func kphToBeaufort(_ kph: Double) -> Int {
        switch kph {
            case ..<1    : return 0
            case 1..<6   : return 1
            case 6..<12  : return 2
            case 12..<20 : return 3
            case 20..<29 : return 4
            case 29..<39 : return 5
            case 39..<50 : return 6
            case 50..<62 : return 7
            case 62..<75 : return 8
            default      : return 9
        }
    }
}
