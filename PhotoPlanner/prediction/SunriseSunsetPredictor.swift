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
    
    static let coastal   : RemoteWeatherConfiguration = RemoteWeatherConfiguration(samplingDistanceKilometres: 150)
    static let inland    : RemoteWeatherConfiguration = RemoteWeatherConfiguration(samplingDistanceKilometres: 100)
    static let telephoto : RemoteWeatherConfiguration = RemoteWeatherConfiguration(samplingDistanceKilometres: 150)
    static let wideAngle : RemoteWeatherConfiguration = RemoteWeatherConfiguration(samplingDistanceKilometres:  75)


    func getDailyTimeline(at location: CLLocationCoordinate2D, on date: Date, shootAzimuth: Double) async throws -> DailyQualityTimeline {
        let timeZone   : TimeZone = await Helper.fetchTimeZone(for: location)
        var calendar   : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfDay : Date = calendar.startOfDay(for: date)
        let endOfDay   : Date = startOfDay.addingTimeInterval(86400)
        
        let hourlyForecast : Forecast<HourWeather> = try await weatherService.weather(for: CLLocation(latitude: location.latitude, longitude: location.longitude), including: .hourly(startDate: startOfDay, endDate: endOfDay))
                
        let dayHours : [HourWeather] = hourlyForecast.forecast.filter {
            $0.date >= startOfDay && $0.date < endOfDay
        }

        guard !dayHours.isEmpty else { throw PredictionError.noForecastData }

        // Find indices of slots that bracket horizon crossings
        var horizonBrackets : Set<Int> = []
        for i in 1..<dayHours.count {
            let prevAlt : Double = calcSunPos(at: location, time: dayHours[i - 1].date).altitude
            let currAlt : Double = calcSunPos(at: location, time: dayHours[i].date).altitude
            if (prevAlt < 0 && currAlt >= 0) || (prevAlt >= 0 && currAlt < 0) {
                horizonBrackets.insert(i - 1)
                horizonBrackets.insert(i)
            }
        }
                
        let slots : [DailyQualityTimeline.HourSlot] = dayHours.enumerated().map { index, hour in
            let sunPos      : SunPos               = calcSunPos(at: location, time: hour.date)
            let directional : DirectionalCloudInfo = getDirectionalInfo(sunAzimuth:   sunPos.azimuth, shootAzimuth: shootAzimuth)
            let localWindow : [HourWeather]        = hourlyForecast.forecast.filter {
                abs($0.date.timeIntervalSince(hour.date)) <= 3600
            }

            let isBracket    : Bool = horizonBrackets.contains(index)
            let isSunUp      : Bool = sunPos.altitude > -6 || isBracket
            let isGoldenHour : Bool = (sunPos.altitude >= -6 && sunPos.altitude <= 12) || isBracket

            // If this slot brackets a horizon crossing treat it as
            // altitude 2° (peak golden hour) for scoring purposes
            let scoringAltitude : Double = isBracket ? 2.0 : sunPos.altitude

            let score : SunriseSunsetScore? = isSunUp ? self.calcScore(window: localWindow, primary: hour, event: SolarEvent(time: hour.date, type: .goldenHour), directional: directional, sunAltitude: scoringAltitude) : nil

            return DailyQualityTimeline.HourSlot(time: hour.date, score: score, sunAltitude: sunPos.altitude, sunAzimuth: sunPos.azimuth, isSunUp: isSunUp, isGoldenHour: isGoldenHour)
        }

        let solarNoon   : Date                           = getSolarNoonTime(at: location, startOfDay: startOfDay)

        let bestSunrise : DailyQualityTimeline.HourSlot? = slots.filter { $0.time < solarNoon && $0.isGoldenHour && $0.score != nil }.max { gradeValue($0.score!.overall) < gradeValue($1.score!.overall) }

        let bestSunset  : DailyQualityTimeline.HourSlot? = slots.filter { $0.time >= solarNoon && $0.isGoldenHour && $0.score != nil }.max { gradeValue($0.score!.overall) < gradeValue($1.score!.overall) }
                
        return DailyQualityTimeline(date: date, slots: slots, bestSunrise: bestSunrise, bestSunset: bestSunset, timeZone: timeZone)
    }
    
    func getDirectionalInfo(sunAzimuth: Double, shootAzimuth: Double) -> DirectionalCloudInfo {
        var diff = (shootAzimuth - sunAzimuth).truncatingRemainder(dividingBy: 360)
        if diff >  180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        let absDiff = abs(diff)

        return DirectionalCloudInfo(sunAzimuth: sunAzimuth, shootAzimuth: shootAzimuth, angularDifference: absDiff, shootingTowardSun: absDiff < 45, shootingAwaySun: absDiff > 135)
    }

    func calcScore(window: [HourWeather], primary: HourWeather, event: SolarEvent, directional: DirectionalCloudInfo, sunAltitude: Double) -> SunriseSunsetScore {
        var reasons: [String] = []
        
        // Directional context
        switch directional.angularDifference {
            case ..<45:
                reasons.append("Shooting toward sun: backlit, lens flare risk")
            case 45..<90:
                reasons.append("Sun at \(Int(directional.angularDifference))° : strong sidelight")
            case 90..<135:
                reasons.append("Sun at \(Int(directional.angularDifference))° : soft sidelight")
            default:
                reasons.append("Shooting away from sun: reflected colour on clouds")
        }

        let altitudeScore: Double
        switch sunAltitude {
            case ..<(-6):
                // Civil twilight: blue hour, still worth scoring
                altitudeScore = 0.6
            case (-6)..<0:
                // Just below horizon: peak blue hour
                altitudeScore = 0.9
            case 0..<6:
                // Just above horizon: golden hour peak
                altitudeScore = 1.0
            case 6..<12:
                // Still golden light but fading
                altitudeScore = 0.7
            case 12..<20:
                // Warm light but no longer golden
                altitudeScore = 0.3
            default:
                // Midday: irrelevant for sunrise/sunset prediction
                altitudeScore = 0.05
        }
        
        // Cloud score: varies by shooting direction
        let cloud     : Double = primary.cloudCover   // 0.0–1.0
        let cloudScore: Double

        if directional.shootingTowardSun {
            switch cloud {
                case ..<0.1:
                    cloudScore = 0.5
                    reasons.append("Clear sky toward sun: clean but limited colour")
                case 0.1..<0.25:
                    cloudScore = 0.85
                    reasons.append("Light cloud toward sun: good colour potential")
                case 0.25..<0.45:
                    cloudScore = 1.0
                    reasons.append("Scattered cloud toward sun: backlit drama likely")
                case 0.45..<0.60:
                    cloudScore = 0.7
                    reasons.append("Broken cloud toward sun: colour possible")
                case 0.60..<0.80:
                    cloudScore = 0.3
                    reasons.append("Heavy cloud toward sun: colour burst likely blocked")
                default:
                    cloudScore = 0.05
                    reasons.append("Solid overcast toward sun: colour burst blocked")
            }

        } else if directional.shootingAwaySun {
            switch cloud {
                case ..<0.15:
                    cloudScore = 0.25
                    reasons.append("Clear sky ahead: nothing to reflect colour onto")
                case 0.15..<0.40:
                    cloudScore = 0.85
                    reasons.append("Clouds ahead will catch reflected colour")
                case 0.40..<0.65:
                    cloudScore = 1.0
                    reasons.append("Good cloud canvas ahead for reflected colour")
                case 0.65..<0.85:
                    cloudScore = 0.45
                    reasons.append("Heavy cloud ahead: colour may be muted")
                default:
                    cloudScore = 0.1
                    reasons.append("Solid overcast ahead: flat light likely")
            }

        } else {
            // Sidelight
            switch cloud {
                case ..<0.1     : cloudScore = 0.45
                case 0.1..<0.3  : cloudScore = 0.75
                case 0.3..<0.5  : cloudScore = 0.95
                case 0.5..<0.7  : cloudScore = 0.7
                case 0.7..<0.85 : cloudScore = 0.3
                default         : cloudScore = 0.05
            }
        }

        // Tighten humidity: maritime/coastal locations penalised more
        let humidity      : Double = primary.humidity
        let humidityScore : Double
        switch humidity {
            case ..<0.35:
                humidityScore = 1.0
                reasons.append("Low humidity: crisp colours expected")
            case 0.35..<0.50:
                humidityScore = 0.8
            case 0.50..<0.65:
                humidityScore = 0.55
                reasons.append("Moderate humidity: some haze likely")
            case 0.65..<0.80:
                humidityScore = 0.3
                reasons.append("High humidity: hazy colours likely")
            default:
                humidityScore = 0.1
                reasons.append("Very high humidity: significant haze expected")
        }
        
        let humidityCap: Double
        switch humidity {
            case ..<0.50     : humidityCap = 1.00   // no cap
            case 0.50..<0.65 : humidityCap = 0.80   // max "Great"
            case 0.65..<0.75 : humidityCap = 0.64   // max "Good"
            case 0.75..<0.85 : humidityCap = 0.48   // max "Fair"
            default          : humidityCap = 0.30   // max "Poor", very humid, colours washed out
        }
        
        let conditionPenalty: Double
        switch primary.condition {

            // Clear: full potential
            case .clear, .mostlyClear                            : conditionPenalty = 1.0

            // Partial cloud: good potential
            case .partlyCloudy                                   : conditionPenalty = 0.95

            // Mostly cloudy: reduced
            case .mostlyCloudy                                   : conditionPenalty = 0.6

            // Full overcast: flat light
            case .cloudy                                         : conditionPenalty = 0.35

            // Atmospheric: haze kills colour
            case .haze                                           : conditionPenalty = 0.4
            case .smoky                                          : conditionPenalty = 0.3
            case .blowingDust                                    : conditionPenalty = 0.2
            case .foggy                                          : conditionPenalty = 0.1

            // Temperature extremes: not directly relevant to colour
            // but often associated with haze or poor visibility
            case .hot                                            : conditionPenalty = 0.7
            case .frigid                                         : conditionPenalty = 0.8 // cold clear air is often very crisp

            // Light precipitation: can still produce colour
            case .drizzle, .freezingDrizzle, .sunShowers         : conditionPenalty = 0.7 // it was 0.4, moved to 0.7-0.8 might be better
            case .sunFlurries                                    : conditionPenalty = 0.5 // snow flurries with sun can be beautiful

            // Moderate precipitation
            case .rain, .sleet, .flurries                        : conditionPenalty = 0.2
            case .wintryMix, .freezingRain                       : conditionPenalty = 0.15

            // Heavy precipitation
            case .heavyRain, .snow, .hail                        : conditionPenalty = 0.05
            case .heavySnow, .blowingSnow                        : conditionPenalty = 0.05
            case .blizzard                                       : conditionPenalty = 0.02

            // Storms
            case .isolatedThunderstorms, .scatteredThunderstorms : conditionPenalty = 0.15
            case .strongStorms, .thunderstorms                   : conditionPenalty = 0.05

            // Tropical hazards
            case .tropicalStorm                                  : conditionPenalty = 0.05
            case .hurricane                                      : conditionPenalty = 0.02
            default                                              : conditionPenalty = 1.0
        }

        // Visibility: weight bad visibility more harshly
        let visibilityKm    : Double = primary.visibility.converted(to: .kilometers).value
        let visibilityScore : Double
        switch visibilityKm {
            case 25...   : visibilityScore = 1.0
            case 15..<25 : visibilityScore = 0.8
            case 10..<15 : visibilityScore = 0.6
            case 5..<10  :
                visibilityScore = 0.3
                reasons.append("Reduced visibility: haze or mist present")
            default      :
                visibilityScore = 0.05
                reasons.append("Poor visibility: fog or heavy haze")
        }

        // Low cloud base proxy: tighter threshold
        let likelyLowCloud = cloud > 0.5 && visibilityKm < 10
        if likelyLowCloud && directional.shootingTowardSun {
            reasons.append("Low cloud base likely: colour burst may be above clouds")
        }

        // Rebalanced weights: humidity and visibility penalise more
        var composite : Double = (cloudScore * 0.45) + (humidityScore * 0.30) + (visibilityScore * 0.25)
        let isRainy   : Bool   = window.contains { $0.precipitationChance > 0.4 }
        if isRainy        { composite *= 0.3 }
        if likelyLowCloud { composite *= 0.6 }

        // Wind bonus only if also low humidity: breezy + humid isn't better
        let windKph : Double = primary.wind.speed.converted(to: .kilometersPerHour).value
        if windKph > 20 && humidity < 0.6 {
            composite += 0.05
            reasons.append("Breezy and dry: atmosphere likely clear")
        }

        // Apply condition as a multiplier
        composite *= conditionPenalty

        // Apply humidity as a hard cap: this is the key change
        composite = min(composite, humidityCap)
        
        // Altitude proximity: applied last as a hard multiplier
        // so midday hours can never score well regardless of conditions
        composite *= altitudeScore
        
        composite = min(1.0, max(0.0, composite))

        // Raise the bar for top grades
        let grade: SunriseSunsetScore.Grade
        switch composite {
            case ..<0.30     : grade = .poor
            case 0.30..<0.48 : grade = .fair
            case 0.48..<0.64 : grade = .good
            case 0.64..<0.80 : grade = .great
            default          : grade = .grand
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
        let jd         : Double = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let n          : Double = jd - 2451545.0

        let L          : Double = (280.46 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let g          : Double = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360)
        let gRad       : Double = g * .pi / 180
        let lambda     : Double = L + 1.915 * sin(gRad) + 0.020 * sin(2 * gRad)

        let epsilon    : Double = 23.439 - 0.0000004 * n
        let epsilonRad : Double = epsilon * .pi / 180
        let lambdaRad  : Double = lambda  * .pi / 180

        let sinDec     : Double = sin(epsilonRad) * sin(lambdaRad)
        let dec        : Double = asin(sinDec)

        // Normalize RA to 0 - 360
        var raNorm     : Double = atan2(cos(epsilonRad) * sin(lambdaRad), cos(lambdaRad)) * 180 / .pi
        if raNorm < 0 { raNorm += 360 }

        // IAU 1982 GMST, same formula as moonPosition
        let jd0        : Double = floor(jd - 0.5) + 0.5
        let T0         : Double = (jd0 - 2451545.0) / 36525.0
        let utH        : Double = (jd - jd0) * 24.0

        let gmst0      : Double = (6.697374558 + 2400.0513369  * T0 + 0.0000258622  * T0 * T0 - 1.7222e-9     * T0 * T0 * T0) * 15.0

        let gmst       : Double = (gmst0 + 360.98564724 * utH / 24.0).truncatingRemainder(dividingBy: 360)

        // Local Hour Angle
        var lha        : Double = (gmst + coordinate.longitude - raNorm).truncatingRemainder(dividingBy: 360)
        if lha < 0 { lha += 360 }
        let lhaRad     : Double = lha * .pi / 180
        let latRad     : Double = coordinate.latitude * .pi / 180

        let sinAlt     : Double = sin(latRad) * sin(dec) + cos(latRad) * cos(dec) * cos(lhaRad)
        let altitude   : Double = asin(sinAlt) * 180 / .pi

        let cosAz      : Double = (sin(dec) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(sinAlt)))
        var azimuth    : Double = acos(max(-1, min(1, cosAz))) * 180 / .pi
        if sin(lhaRad) > 0 { azimuth = 360 - azimuth }

        return SunPos(altitude: altitude, azimuth: azimuth)
    }
        
    private func gradeValue(_ grade: SunriseSunsetScore.Grade) -> Int {
        switch grade {
            case .poor  : return 0
            case .fair  : return 1
            case .good  : return 2
            case .great : return 3
            case .grand : return 4
        }
    }
}


extension SunriseSunsetPredictor {

    func blendCameraAndRemoteScores(cameraScore: SunriseSunsetScore, remoteScore: SunriseSunsetScore, remoteWeightFraction: Double = 0.6) -> SunriseSunsetScore {
        let cameraWeightFraction   : Double = 1.0 - remoteWeightFraction

        let blendedCloudScore      : Double = cameraScore.cloudScore      * cameraWeightFraction + remoteScore.cloudScore      * remoteWeightFraction
        let blendedHumidityScore   : Double = cameraScore.humidityScore   * cameraWeightFraction + remoteScore.humidityScore   * remoteWeightFraction
        let blendedVisibilityScore : Double = cameraScore.visibilityScore * cameraWeightFraction + remoteScore.visibilityScore * remoteWeightFraction

            // Prefix remote reasoning so the photographer can distinguish
            // which conditions are local vs in the sun's direction
            let remoteReasoning = remoteScore.reasoning.map {
                "At \(Int(remoteWeightFraction * 100))km: \($0)"
            }
        let combinedReasoning : Array<String> = cameraScore.reasoning + remoteReasoning

        var composite = (blendedCloudScore * 0.45) + (blendedHumidityScore * 0.30) + (blendedVisibilityScore * 0.25)
        composite = min(1.0, max(0.0, composite))

        let grade: SunriseSunsetScore.Grade
        switch composite {
            case ..<0.30     : grade = .poor
            case 0.30..<0.48 : grade = .fair
            case 0.48..<0.64 : grade = .good
            case 0.64..<0.80 : grade = .great
            default          : grade = .grand
        }

        return SunriseSunsetScore(overall: grade, cloudScore: blendedCloudScore, humidityScore: blendedHumidityScore, visibilityScore: blendedVisibilityScore, reasoning: combinedReasoning)
    }
    
    /// Fetches weather at the camera location plus two remote points
    /// one in the direction of sunrise and one in the direction of sunset 
    /// then blends the scores for a more accurate prediction.
    func getBlendedDailyTimeline(at cameraLocation: CLLocationCoordinate2D, on date: Date, shootAzimuth: Double, configuration: RemoteWeatherConfiguration = SunriseSunsetPredictor.inland) async throws -> BlendedDailyQualityTimeline {

        let timeZone : TimeZone = await Helper.fetchTimeZone(for: cameraLocation)
        var calendar : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay   = startOfDay.addingTimeInterval(86400)

        // Calculate approximate sunrise and sunset times by finding
        // when the sun crosses the horizon during the day
        let approximateSunriseTime : Date? = calcApproximateHorizonCrossingTime(at: cameraLocation, startOfDay: startOfDay, lookingForRising: true)
        let approximateSunsetTime  : Date? = calcApproximateHorizonCrossingTime(at: cameraLocation, startOfDay: startOfDay, lookingForRising: false )

        // Calculate sun azimuths at sunrise and sunset
        let sunriseAzimuth : Double = approximateSunriseTime.map { calcSunPos(at: cameraLocation, time: $0).azimuth } ?? 90.0   // default to east if no sunrise found
        let sunsetAzimuth  : Double = approximateSunsetTime.map { calcSunPos(at: cameraLocation, time: $0).azimuth } ?? 270.0  // default to west if no sunset found

        // Calculate remote coordinates in the sun's direction
        let sunriseRemoteCoordinate : CLLocationCoordinate2D = await cameraLocation.coordinateByOffsetting(distanceKilometres: configuration.samplingDistanceKilometres, bearingDegrees: sunriseAzimuth)
        let sunsetRemoteCoordinate  : CLLocationCoordinate2D = await cameraLocation.coordinateByOffsetting(distanceKilometres: configuration.samplingDistanceKilometres, bearingDegrees: sunsetAzimuth)

        let sunriseRemoteLocation   : CLLocation = CLLocation(latitude: sunriseRemoteCoordinate.latitude, longitude: sunriseRemoteCoordinate.longitude)
        let sunsetRemoteLocation    : CLLocation = CLLocation(latitude:  sunsetRemoteCoordinate.latitude,longitude: sunsetRemoteCoordinate.longitude)

        // Fetch all three forecasts in parallel
        async let cameraForecastTask  = weatherService.weather(for: CLLocation(latitude: cameraLocation.latitude, longitude: cameraLocation.longitude),including: .hourly(startDate: startOfDay, endDate: endOfDay))
        async let sunriseForecastTask = weatherService.weather(for: sunriseRemoteLocation,including: .hourly(startDate: startOfDay, endDate: endOfDay))
        async let sunsetForecastTask  = weatherService.weather(for: sunsetRemoteLocation, including: .hourly(startDate: startOfDay, endDate: endOfDay))

        let (cameraForecast, sunriseForecast, sunsetForecast) = try await (cameraForecastTask, sunriseForecastTask, sunsetForecastTask)

        // Filter to the requested day
        let cameraHours  : [HourWeather] = cameraForecast.forecast.filter { $0.date >= startOfDay && $0.date < endOfDay }
        let sunriseHours : [HourWeather] = sunriseForecast.forecast.filter { $0.date >= startOfDay && $0.date < endOfDay }
        let sunsetHours  : [HourWeather] = sunsetForecast.forecast.filter { $0.date >= startOfDay && $0.date < endOfDay }

        guard !cameraHours.isEmpty else { throw PredictionError.noForecastData }

        // Find indices of slots that bracket horizon crossings
        var horizonBracketIndices: Set<Int> = []
        for index in 1..<cameraHours.count {
            let previousAltitude  : Double = calcSunPos(at: cameraLocation, time: cameraHours[index - 1].date).altitude
            let currentAltitude   : Double = calcSunPos(at: cameraLocation, time: cameraHours[index].date).altitude
            let isRisingCrossing  : Bool   = previousAltitude < 0 && currentAltitude >= 0
            let isSettingCrossing : Bool   = previousAltitude >= 0 && currentAltitude < 0
            if isRisingCrossing || isSettingCrossing {
                horizonBracketIndices.insert(index - 1)
                horizonBracketIndices.insert(index)
            }
        }

        // Determine solar noon to split sunrise and sunset halves
        let solarNoonTime = getSolarNoonTime(at: cameraLocation, startOfDay: startOfDay)

        // Build blended slots
        let slots: [BlendedDailyQualityTimeline.BlendedHourSlot] = cameraHours.enumerated().map { index, cameraHour in

            let currentSunPosition  : SunPos               = calcSunPos(at: cameraLocation, time: cameraHour.date)
            let directionalContext  : DirectionalCloudInfo = getDirectionalInfo(sunAzimuth: currentSunPosition.azimuth, shootAzimuth: shootAzimuth)

            let isBracketingHorizon : Bool                 = horizonBracketIndices.contains(index)
            let isSunUp             : Bool                 = currentSunPosition.altitude > -6 || isBracketingHorizon
            let isGoldenHour        : Bool                 = (currentSunPosition.altitude >= -6 && currentSunPosition.altitude <= 12) || isBracketingHorizon

            // Use altitude 2° for bracketing slots so they score
            // as peak golden hour regardless of their measured altitude
            let scoringAltitude     : Double               = isBracketingHorizon ? 2.0 : currentSunPosition.altitude

            guard isSunUp else {
                return BlendedDailyQualityTimeline.BlendedHourSlot(time: cameraHour.date, blendedScore: nil, cameraLocationScore: nil,
                                                                   remoteLocationScore: nil, sunAltitude: currentSunPosition.altitude,
                                                                   sunAzimuth: currentSunPosition.azimuth, isSunUp: false, isGoldenHour: false)
            }

            // Local window for precipitation check
            let cameraLocalWindow = cameraForecast.forecast.filter { abs($0.date.timeIntervalSince(cameraHour.date)) <= 3600 }

            // Score at camera location
            let cameraLocationScore = calcScore(window: cameraLocalWindow, primary: cameraHour, event: SolarEvent(time: cameraHour.date, type: .goldenHour),
                                            directional: directionalContext, sunAltitude: scoringAltitude )

            // Choose the correct remote forecast based on whether
            // this slot is in the sunrise or sunset half of the day
            let isInSunriseHalf : Bool = cameraHour.date < solarNoonTime

            let remoteHours        = isInSunriseHalf ? sunriseHours    : sunsetHours
            let remoteForecastFull = isInSunriseHalf ? sunriseForecast : sunsetForecast

            // Find the matching remote hour for this time slot
            let remoteLocationScore: SunriseSunsetScore? = remoteHours
                .min(by: { abs($0.date.timeIntervalSince(cameraHour.date)) < abs($1.date.timeIntervalSince(cameraHour.date))})
                .map { remoteHour in
                    let remoteLocalWindow = remoteForecastFull.forecast.filter { abs($0.date.timeIntervalSince(remoteHour.date)) <= 3600 }
                    return calcScore(window: remoteLocalWindow, primary: remoteHour, event: SolarEvent(time: remoteHour.date, type: .goldenHour),
                                     directional: directionalContext, sunAltitude: scoringAltitude)
                }

            // Calculate atmospheric tendency for this slot
            let atmosphericTendency : AtmosphericTendency = atmosphericTendency(from: cameraForecast.forecast, at: cameraHour.date)
            
            // Blend camera and remote scores
            let blendedScore: SunriseSunsetScore? = remoteLocationScore.map {
                var blended : SunriseSunsetScore = blendCameraAndRemoteScores(cameraScore: cameraLocationScore, remoteScore: $0, remoteWeightFraction: 0.6)
                // Re-compute composite with tendency bonus
                if atmosphericTendency.tendencyBonus > 0 {
                    var updatedReasons = blended.reasoning
                    if atmosphericTendency.isPostFrontal { updatedReasons.append("Post-frontal clearing: exceptional light possible") }
                    if atmosphericTendency.isPressureRising { updatedReasons.append("Rising pressure: atmosphere clearing") }
                    if atmosphericTendency.isConditionsImproving { updatedReasons.append("Improving conditions: cloud cover decreasing") }

                    // Rebuild score with bonus applied
                    blended = SunriseSunsetScore(
                        overall         : upgradeGradeIfNeeded(blended.overall, bonus: atmosphericTendency.tendencyBonus),
                        cloudScore      : blended.cloudScore,
                        humidityScore   : blended.humidityScore,
                        visibilityScore : blended.visibilityScore,
                        reasoning       : updatedReasons
                    )
                }
                return blended
            } ?? cameraLocationScore

            return BlendedDailyQualityTimeline.BlendedHourSlot(time: cameraHour.date, blendedScore: blendedScore, cameraLocationScore: cameraLocationScore,
                                                               remoteLocationScore: remoteLocationScore, sunAltitude: currentSunPosition.altitude,
                                                               sunAzimuth: currentSunPosition.azimuth, isSunUp: isSunUp, isGoldenHour: isGoldenHour)
        }

        let bestSunrise = slots
            .filter { $0.time < solarNoonTime && $0.isGoldenHour && $0.blendedScore != nil }
            .max { gradeValue($0.blendedScore!.overall) < gradeValue($1.blendedScore!.overall) }

        let bestSunset = slots
            .filter { $0.time >= solarNoonTime && $0.isGoldenHour && $0.blendedScore != nil }
            .max { gradeValue($0.blendedScore!.overall) < gradeValue($1.blendedScore!.overall) }

        return BlendedDailyQualityTimeline(date: date, slots: slots, bestSunrise: bestSunrise, bestSunset: bestSunset, timeZone: timeZone,
                                           sunriseRemoteCoordinate: sunriseRemoteCoordinate, sunsetRemoteCoordinate: sunsetRemoteCoordinate)
    }

    func atmosphericTendency(from forecast: [HourWeather], at eventTime: Date) -> AtmosphericTendency {
        // Look at the 12 hours leading up to the event
        let leadupWindow = forecast.filter { $0.date >= eventTime.addingTimeInterval(-12 * 3600) && $0.date <  eventTime }

        guard leadupWindow.count >= 3 else {
            return AtmosphericTendency(isPressureRising: false, isPostFrontal: false, isConditionsImproving: false, tendencyBonus: 0.0)
        }

        // Pressure tendency: compare first and last third of window
        let firstThird             : ArraySlice<HourWeather> = leadupWindow.prefix(leadupWindow.count / 3)
        let lastThird              : ArraySlice<HourWeather> = leadupWindow.suffix(leadupWindow.count / 3)
        let averageEarlyPressure   : Double                  = firstThird.map { $0.pressure.converted(to: .hectopascals).value }.reduce(0, +) / Double(firstThird.count)
        let averageLatePressure    : Double                  = lastThird.map { $0.pressure.converted(to: .hectopascals).value }.reduce(0, +) / Double(lastThird.count)
        let pressureChangePascals  : Double                  = averageLatePressure - averageEarlyPressure
        let isPressureRising       : Bool                    = pressureChangePascals > 1.0   // rising > 1 hPa

        // Post-frontal detection: precipitation in earlier hours
        // followed by clearing conditions near the event
        let hadRecentPrecipitation = leadupWindow.prefix(leadupWindow.count / 2).contains { $0.precipitationChance > 0.4 }
        let isNowClearing          : Bool = leadupWindow.suffix(3).allSatisfy { $0.cloudCover < 0.6 }
        let isPostFrontal          : Bool = hadRecentPrecipitation && isNowClearing

        // Improving conditions: cloud cover trend
        let earlyCloudCover       : Double = firstThird.map(\.cloudCover).reduce(0, +) / Double(firstThird.count)
        let lateCloudCover        : Double = lastThird.map(\.cloudCover).reduce(0, +) / Double(lastThird.count)
        let isConditionsImproving : Bool   = lateCloudCover < earlyCloudCover - 0.15

        // Calculate bonus
        var tendencyBonus : Double = 0.0
        if isPressureRising      { tendencyBonus += 0.08 }
        if isPostFrontal         { tendencyBonus += 0.12 }
        if isConditionsImproving { tendencyBonus += 0.06 }

        return AtmosphericTendency(isPressureRising: isPressureRising, isPostFrontal: isPostFrontal, isConditionsImproving: isConditionsImproving, tendencyBonus: min(0.20, tendencyBonus))
    }

    private func calcApproximateHorizonCrossingTime(at coordinate: CLLocationCoordinate2D, startOfDay: Date, lookingForRising: Bool) -> Date? {
        let samplingIntervalSeconds : Double = 600.0   // 10 minutes
        var previousAltitude        : Double?

        var   sampleTime : Date = startOfDay
        while sampleTime < startOfDay.addingTimeInterval(86400) {
            let currentAltitude : Double = calcSunPos(at: coordinate, time: sampleTime).altitude

            if let previous = previousAltitude {
                let isRisingCrossing  : Bool = previous < 0 && currentAltitude >= 0
                let isSettingCrossing : Bool = previous >= 0 && currentAltitude < 0

                if lookingForRising && isRisingCrossing {
                    // Interpolate for a more precise crossing time
                    let fraction : Double = -previous / (currentAltitude - previous)
                    return sampleTime.addingTimeInterval(-samplingIntervalSeconds + fraction * samplingIntervalSeconds)
                }
                if !lookingForRising && isSettingCrossing {
                    let fraction : Double = -previous / (currentAltitude - previous)
                    return sampleTime.addingTimeInterval(-samplingIntervalSeconds + fraction * samplingIntervalSeconds)
                }
            }

            previousAltitude = currentAltitude
            sampleTime       = sampleTime.addingTimeInterval(samplingIntervalSeconds)
        }
        return nil
    }
    
    private func upgradeGradeIfNeeded(_ grade: SunriseSunsetScore.Grade, bonus: Double) -> SunriseSunsetScore.Grade {
        // Only upgrade one level at most to avoid over-predicting
        guard bonus >= 0.08 else { return grade }
        switch grade {
            case .poor  : return .fair
            case .fair  : return .good
            case .good  : return .great
            case .great : return .grand
            case .grand : return .grand
        }
    }
}
