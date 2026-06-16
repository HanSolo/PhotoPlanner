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
    
    private let weatherService   : WeatherService             = WeatherService.shared
    
    static let coastal           : RemoteWeatherConfiguration = RemoteWeatherConfiguration(nearSamplingDistanceKilometres: 45, farSamplingDistanceKilometres: 90)
    static let inland            : RemoteWeatherConfiguration = RemoteWeatherConfiguration(nearSamplingDistanceKilometres: 35, farSamplingDistanceKilometres: 70)
    static let telephoto         : RemoteWeatherConfiguration = RemoteWeatherConfiguration(nearSamplingDistanceKilometres: 45, farSamplingDistanceKilometres: 90)
    static let wideAngle         : RemoteWeatherConfiguration = RemoteWeatherConfiguration(nearSamplingDistanceKilometres: 25, farSamplingDistanceKilometres: 55)

    static let cameraBlendWeight : Double                     = 0.30
    static let nearBlendWeight   : Double                     = 0.40
    static let farBlendWeight    : Double                     = 0.30
    
    
    
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

    // Blends camera, near (prominent cloud zone) and far (gateway zone) scores using the fixed weighting. Normalises by the total weight actually used so it degrades gracefully if a remote score is nil.
    func blendThreePointScores(cameraScore: SunriseSunsetScore, nearScore: SunriseSunsetScore?, farScore: SunriseSunsetScore?) -> SunriseSunsetScore {
        var weightedCloud      : Double        = cameraScore.cloudScore      * SunriseSunsetPredictor.cameraBlendWeight
        var weightedHumidity   : Double        = cameraScore.humidityScore   * SunriseSunsetPredictor.cameraBlendWeight
        var weightedVisibility : Double        = cameraScore.visibilityScore * SunriseSunsetPredictor.cameraBlendWeight
        var totalWeight        : Double        = SunriseSunsetPredictor.cameraBlendWeight
        var combinedReasoning  : Array<String> = cameraScore.reasoning

        if let nearScore {
            weightedCloud      += nearScore.cloudScore      * SunriseSunsetPredictor.nearBlendWeight
            weightedHumidity   += nearScore.humidityScore   * SunriseSunsetPredictor.nearBlendWeight
            weightedVisibility += nearScore.visibilityScore * SunriseSunsetPredictor.nearBlendWeight
            totalWeight        += SunriseSunsetPredictor.nearBlendWeight
            combinedReasoning  += nearScore.reasoning.map { "Near: \($0)" }
        }

        if let farScore {
            weightedCloud      += farScore.cloudScore      * SunriseSunsetPredictor.farBlendWeight
            weightedHumidity   += farScore.humidityScore   * SunriseSunsetPredictor.farBlendWeight
            weightedVisibility += farScore.visibilityScore * SunriseSunsetPredictor.farBlendWeight
            totalWeight        += SunriseSunsetPredictor.farBlendWeight
            combinedReasoning  += farScore.reasoning.map { "Far: \($0)" }
        }

        guard totalWeight > 0 else { return cameraScore }

        let blendedCloudScore      : Double = weightedCloud      / totalWeight
        let blendedHumidityScore   : Double = weightedHumidity   / totalWeight
        let blendedVisibilityScore : Double = weightedVisibility / totalWeight

        var composite : Double = (blendedCloudScore * 0.45) + (blendedHumidityScore * 0.30) + (blendedVisibilityScore * 0.25)
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
    
    // Fetches weather at the camera location plus four remote points: near + far in the direction of sunrise, and near + far in the direction of sunset, then blends the three relevant points per event (camera + near + far) for a more accurate prediction.
    func getBlendedDailyTimeline(at cameraLocation: CLLocationCoordinate2D, on date: Date, shootAzimuth: Double, configuration: RemoteWeatherConfiguration = SunriseSunsetPredictor.inland) async throws -> BlendedDailyQualityTimeline {

    let timeZone : TimeZone = await Helper.fetchTimeZone(for: cameraLocation)
    var calendar : Calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone

    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay   = startOfDay.addingTimeInterval(86400)

    // Calculate approximate sunrise and sunset times by finding
    // when the sun crosses the horizon during the day
    let approximateSunriseTime : Date? = calcApproximateHorizonCrossingTime(at: cameraLocation, startOfDay: startOfDay, lookingForRising: true)
    let approximateSunsetTime  : Date? = calcApproximateHorizonCrossingTime(at: cameraLocation, startOfDay: startOfDay, lookingForRising: false)

    // Calculate sun azimuths at sunrise and sunset
    let sunriseAzimuth : Double = approximateSunriseTime.map { SolarCalculator.calcSunPosition(at: cameraLocation, time: $0).azimuth } ?? 90.0   // default to east if no sunrise found
    let sunsetAzimuth  : Double = approximateSunsetTime.map  { SolarCalculator.calcSunPosition(at: cameraLocation, time: $0).azimuth } ?? 270.0  // default to west if no sunset found

    // Calculate the four remote coordinates: near + far toward each event
    let sunriseNearCoordinate : CLLocationCoordinate2D = await cameraLocation.coordinateByOffsetting(distanceKilometres: configuration.nearSamplingDistanceKilometres, bearingDegrees: sunriseAzimuth)
    let sunriseFarCoordinate  : CLLocationCoordinate2D = await cameraLocation.coordinateByOffsetting(distanceKilometres: configuration.farSamplingDistanceKilometres,  bearingDegrees: sunriseAzimuth)
    let sunsetNearCoordinate  : CLLocationCoordinate2D = await cameraLocation.coordinateByOffsetting(distanceKilometres: configuration.nearSamplingDistanceKilometres, bearingDegrees: sunsetAzimuth)
    let sunsetFarCoordinate   : CLLocationCoordinate2D = await cameraLocation.coordinateByOffsetting(distanceKilometres: configuration.farSamplingDistanceKilometres,  bearingDegrees: sunsetAzimuth)

    let cameraCLLocation      : CLLocation = CLLocation(latitude: cameraLocation.latitude,          longitude: cameraLocation.longitude)
    let sunriseNearLocation   : CLLocation = CLLocation(latitude: sunriseNearCoordinate.latitude,   longitude: sunriseNearCoordinate.longitude)
    let sunriseFarLocation    : CLLocation = CLLocation(latitude: sunriseFarCoordinate.latitude,    longitude: sunriseFarCoordinate.longitude)
    let sunsetNearLocation    : CLLocation = CLLocation(latitude: sunsetNearCoordinate.latitude,    longitude: sunsetNearCoordinate.longitude)
    let sunsetFarLocation     : CLLocation = CLLocation(latitude: sunsetFarCoordinate.latitude,     longitude: sunsetFarCoordinate.longitude)
        
    // Fetch all five forecasts in parallel
    async let cameraForecastTask      = weatherService.weather(for: cameraCLLocation,    including: .hourly(startDate: startOfDay, endDate: endOfDay))
    async let sunriseNearForecastTask = weatherService.weather(for: sunriseNearLocation, including: .hourly(startDate: startOfDay, endDate: endOfDay))
    async let sunriseFarForecastTask  = weatherService.weather(for: sunriseFarLocation,  including: .hourly(startDate: startOfDay, endDate: endOfDay))
    async let sunsetNearForecastTask  = weatherService.weather(for: sunsetNearLocation,  including: .hourly(startDate: startOfDay, endDate: endOfDay))
    async let sunsetFarForecastTask   = weatherService.weather(for: sunsetFarLocation,   including: .hourly(startDate: startOfDay, endDate: endOfDay))

    let (cameraForecast, sunriseNearForecast, sunriseFarForecast, sunsetNearForecast, sunsetFarForecast) = try await (cameraForecastTask, sunriseNearForecastTask, sunriseFarForecastTask, sunsetNearForecastTask, sunsetFarForecastTask)

    // Filter to the requested day
    let cameraHours      : [HourWeather] = cameraForecast.forecast.filter      { $0.date >= startOfDay && $0.date < endOfDay }
    let sunriseNearHours : [HourWeather] = sunriseNearForecast.forecast.filter { $0.date >= startOfDay && $0.date < endOfDay }
    let sunriseFarHours  : [HourWeather] = sunriseFarForecast.forecast.filter  { $0.date >= startOfDay && $0.date < endOfDay }
    let sunsetNearHours  : [HourWeather] = sunsetNearForecast.forecast.filter  { $0.date >= startOfDay && $0.date < endOfDay }
    let sunsetFarHours   : [HourWeather] = sunsetFarForecast.forecast.filter   { $0.date >= startOfDay && $0.date < endOfDay }

    guard !cameraHours.isEmpty else { throw PredictionError.noForecastData }

    // Find indices of slots that bracket horizon crossings
    var horizonBracketIndices: Set<Int> = []
    for index in 1..<cameraHours.count {
        let previousAltitude  : Double = SolarCalculator.calcSunPosition(at: cameraLocation, time: cameraHours[index - 1].date).altitude
        let currentAltitude   : Double = SolarCalculator.calcSunPosition(at: cameraLocation, time: cameraHours[index].date).altitude
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

        let currentSunPosition  : SunPosition          = SolarCalculator.calcSunPosition(at: cameraLocation, time: cameraHour.date)
        let directionalContext  : DirectionalCloudInfo = getDirectionalInfo(sunAzimuth: currentSunPosition.azimuth, shootAzimuth: shootAzimuth)

        let isBracketingHorizon : Bool                 = horizonBracketIndices.contains(index)
        let isSunUp             : Bool                 = currentSunPosition.altitude > -6 || isBracketingHorizon
        let isGoldenHour        : Bool                 = (currentSunPosition.altitude >= -6 && currentSunPosition.altitude <= 12) || isBracketingHorizon

        // Use altitude 2° for bracketing slots so they score as peak golden hour regardless of their measured altitude
        let scoringAltitude     : Double               = isBracketingHorizon ? 2.0 : currentSunPosition.altitude

        guard isSunUp else {
            return BlendedDailyQualityTimeline.BlendedHourSlot(time: cameraHour.date, blendedScore: nil, cameraLocationScore: nil,
                                                               remoteLocationScore: nil, sunAltitude: currentSunPosition.altitude,
                                                               sunAzimuth: currentSunPosition.azimuth, isSunUp: false, isGoldenHour: false)
        }

        // Score at camera location
        let cameraLocalWindow   = cameraForecast.forecast.filter { abs($0.date.timeIntervalSince(cameraHour.date)) <= 3600 }
        let cameraLocationScore = calcScore(window: cameraLocalWindow, primary: cameraHour, event: SolarEvent(time: cameraHour.date, type: .goldenHour), directional: directionalContext, sunAltitude: scoringAltitude)

        // Choose the correct near/far forecasts based on whether this slot is in the sunrise or sunset half of the day
        let isInSunriseHalf  : Bool                  = cameraHour.date < solarNoonTime

        let nearHours        : [HourWeather]         = isInSunriseHalf ? sunriseNearHours    : sunsetNearHours
        let farHours         : [HourWeather]         = isInSunriseHalf ? sunriseFarHours     : sunsetFarHours
        let nearForecastFull : Forecast<HourWeather> = isInSunriseHalf ? sunriseNearForecast : sunsetNearForecast
        let farForecastFull  : Forecast<HourWeather> = isInSunriseHalf ? sunriseFarForecast  : sunsetFarForecast

        // Near point score (prominent cloud zone)
        let nearLocationScore: SunriseSunsetScore? = nearHours
            .min(by: { abs($0.date.timeIntervalSince(cameraHour.date)) < abs($1.date.timeIntervalSince(cameraHour.date)) })
            .map { nearHour in
                let nearLocalWindow : [HourWeather] = nearForecastFull.forecast.filter { abs($0.date.timeIntervalSince(nearHour.date)) <= 3600 }
                return calcScore(window: nearLocalWindow, primary: nearHour, event: SolarEvent(time: nearHour.date, type: .goldenHour), directional: directionalContext, sunAltitude: scoringAltitude)
            }

        // Far point score (gateway zone)
        let farLocationScore: SunriseSunsetScore? = farHours
            .min(by: { abs($0.date.timeIntervalSince(cameraHour.date)) < abs($1.date.timeIntervalSince(cameraHour.date)) })
            .map { farHour in
                let farLocalWindow : [HourWeather] = farForecastFull.forecast.filter { abs($0.date.timeIntervalSince(farHour.date)) <= 3600 }
                return calcScore(window: farLocalWindow, primary: farHour, event: SolarEvent(time: farHour.date, type: .goldenHour), directional: directionalContext, sunAltitude: scoringAltitude)
            }

        // Blend the three points (camera + near + far)
        var blendedScore : SunriseSunsetScore = blendThreePointScores(cameraScore: cameraLocationScore, nearScore: nearLocationScore, farScore: farLocationScore)

        // Apply atmospheric tendency bonus from the camera forecast
        let atmosphericTendency : AtmosphericTendency = getAtmosphericTendency(from: cameraForecast.forecast, at: cameraHour.date)
        if atmosphericTendency.tendencyBonus > 0 {
            var updatedReasons = blendedScore.reasoning
            if atmosphericTendency.isPostFrontal        { updatedReasons.append("Post-frontal clearing: exceptional light possible") }
            if atmosphericTendency.isPressureRising     { updatedReasons.append("Rising pressure: atmosphere clearing") }
            if atmosphericTendency.isConditionsImproving { updatedReasons.append("Improving conditions: cloud cover decreasing") }

            blendedScore = SunriseSunsetScore(
                overall         : upgradeGradeIfNeeded(blendedScore.overall, bonus: atmosphericTendency.tendencyBonus),
                cloudScore      : blendedScore.cloudScore,
                humidityScore   : blendedScore.humidityScore,
                visibilityScore : blendedScore.visibilityScore,
                reasoning       : updatedReasons
            )
        }

        // Expose the near score as the representative remote score for the overlay
        return BlendedDailyQualityTimeline.BlendedHourSlot(time: cameraHour.date, blendedScore: blendedScore, cameraLocationScore: cameraLocationScore,
                                                           remoteLocationScore: nearLocationScore, sunAltitude: currentSunPosition.altitude,
                                                           sunAzimuth: currentSunPosition.azimuth, isSunUp: isSunUp, isGoldenHour: isGoldenHour)
    }

    let bestSunrise = slots
        .filter { $0.time < solarNoonTime && $0.isGoldenHour && $0.blendedScore != nil }
        .max { gradeValue($0.blendedScore!.overall) < gradeValue($1.blendedScore!.overall) }

    let bestSunset = slots
        .filter { $0.time >= solarNoonTime && $0.isGoldenHour && $0.blendedScore != nil }
        .max { gradeValue($0.blendedScore!.overall) < gradeValue($1.blendedScore!.overall) }

    // Report the near coordinates as the representative sample points
    return BlendedDailyQualityTimeline(date: date, slots: slots, bestSunrise: bestSunrise, bestSunset: bestSunset, timeZone: timeZone,
                                       sunriseRemoteCoordinate: sunriseNearCoordinate, sunsetRemoteCoordinate: sunsetNearCoordinate)
}
            
    func getDirectionalInfo(sunAzimuth: Double, shootAzimuth: Double) -> DirectionalCloudInfo {
        var diff = (shootAzimuth - sunAzimuth).truncatingRemainder(dividingBy: 360)
        if diff >  180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        let absDiff = abs(diff)
        
        return DirectionalCloudInfo(sunAzimuth: sunAzimuth, shootAzimuth: shootAzimuth, angularDifference: absDiff, shootingTowardSun: absDiff < 45, shootingAwaySun: absDiff > 135)
    }
    
    func getAtmosphericTendency(from forecast: [HourWeather], at eventTime: Date) -> AtmosphericTendency {
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
    
    func calcScore(window: [HourWeather], primary: HourWeather, event: SolarEvent, directional: DirectionalCloudInfo, sunAltitude: Double) -> SunriseSunsetScore {
        var reasons: [String] = []
                
        // Directional context
        switch directional.angularDifference {
            case ..<45    : reasons.append("Shooting toward sun: backlit, lens flare risk")
            case 45..<90  : reasons.append("Sun at \(Int(directional.angularDifference))° : strong sidelight")
            case 90..<135 : reasons.append("Sun at \(Int(directional.angularDifference))° : soft sidelight")
            default       : reasons.append("Shooting away from sun: reflected colour on clouds")
        }

        let altitudeScore: Double
        switch sunAltitude {
            case ..<(-6)  : altitudeScore = 0.6  // Civil twilight: blue hour, still worth scoring
            case (-6)..<0 : altitudeScore = 0.9  // Just below horizon: peak blue hour
            case 0..<6    : altitudeScore = 1.0  // Just above horizon: golden hour peak
            case 6..<12   : altitudeScore = 0.7  // Still golden light but fading
            case 12..<20  : altitudeScore = 0.3  // Warm light but no longer golden
            default       : altitudeScore = 0.05 // Midday: irrelevant for sunrise/sunset prediction
        }

        let cloud        : Double = primary.cloudCover
        let humidity     : Double = primary.humidity
        let visibilityKm : Double = primary.visibility.converted(to: .kilometers).value

        // A solid or near-solid overcast layer during golden hour with
        // good visibility means the sun can illuminate the underside of
        // the cloud from below and the entire sky lights up in orange-red.
        // This is one of the most spectacular sunrise/sunset conditions
        // and must NOT be penalised as "blocked overcast".
        //
        // Conditions required:
        //   - High cloud coverage (> 0.70) -> the "wall"
        //   - Golden hour window, sun low enough to light the cloud base
        //   - Visibility > 8km, can see the illuminated cloud layer
        //   - Humidity < 0.88, not so humid that fog obscures everything
        //   - Shooting toward or perpendicular to sun, not away from it
        let isGoldenHourWindow : Bool = sunAltitude >= -6 && sunAltitude <= 8
        let isSolidOvercast    : Bool = cloud > 0.70
        let visibilityOk       : Bool = visibilityKm > 8
        let humidityOk         : Bool = humidity < 0.95
        let directionOk        : Bool = !directional.shootingAwaySun
        let isCloudCanvas      : Bool = isSolidOvercast && isGoldenHourWindow && visibilityOk && humidityOk && directionOk

        if isCloudCanvas {
            reasons.append("Cloud canvas detected: solid overcast may light up in orange-red")
        }

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
                    cloudScore = 0.5
                    reasons.append("Heavy cloud toward sun: colour possible if gap at horizon")
                default:
                    // Solid overcast toward sun, could be spectacular cloud canvas or could be flat grey nothing, depends on canvas detection
                    if isCloudCanvas {
                        cloudScore = 0.90
                        reasons.append("Solid cloud canvas toward sun: entire sky may light up")
                    } else {
                        cloudScore = 0.10
                        reasons.append("Solid overcast toward sun: colour burst likely blocked")
                    }
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
                case 0.7..<0.85 :
                    cloudScore = isCloudCanvas ? 0.85 : 0.3
                    if isCloudCanvas { reasons.append("Heavy cloud canvas from side: dramatic sidelit wall possible") }
                default         :
                    cloudScore = isCloudCanvas ? 0.80 : 0.05
                    if isCloudCanvas { reasons.append("Solid cloud canvas from side: uniform sidelit glow possible") }
                }
        }
        
        // For cloud canvas conditions moderate-high humidity intensifies colour saturation rather than washing it out,
        // the moisture amplifies the scattering of the low-angle light.
        let humidityScore: Double
        if isCloudCanvas && humidity >= 0.50 && humidity < 0.95 {
            humidityScore = 0.75
            reasons.append("Humid air with cloud canvas: intensified colour saturation likely")
        } else {
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
        }

        // Relaxed for cloud canvas, the cap exists to prevent hazy days scoring well, but a solid cloud layer at golden hour with
        // moderate humidity IS a spectacular condition.
        let humidityCap: Double
        if isCloudCanvas {
            humidityCap = 0.95   // don't cap cloud canvas, let it score high
        } else {
            switch humidity {
                case ..<0.50     : humidityCap = 1.00
                case 0.50..<0.65 : humidityCap = 0.80
                case 0.65..<0.75 : humidityCap = 0.64
                case 0.75..<0.85 : humidityCap = 0.48
                default          : humidityCap = 0.30
            }
        }

        // For cloud canvas .cloudy is actually the desired condition, raise the penalty from 0.35 to 0.85 in that case.
        let conditionPenalty: Double
        switch primary.condition {
            case .clear, .mostlyClear                            : conditionPenalty = 1.0  // Clear: full potential
            case .partlyCloudy                                   : conditionPenalty = 0.95  // Partial cloud: good potential
            case .mostlyCloudy                                   : conditionPenalty = isCloudCanvas ? 0.85 : 0.6 // Mostly cloudy: reduced — unless cloud canvas
            case .cloudy                                         : conditionPenalty = isCloudCanvas ? 0.85 : 0.35 // Full overcast: flat light normally — spectacular if cloud canvas
            case .haze                                           : conditionPenalty = 0.4 // Atmospheric: haze kills colour
            case .smoky                                          : conditionPenalty = 0.3
            case .blowingDust                                    : conditionPenalty = 0.2
            case .foggy                                          : conditionPenalty = 0.1
            case .hot                                            : conditionPenalty = 0.7 // Temperature extremes
            case .frigid                                         : conditionPenalty = 0.8
            case .drizzle, .freezingDrizzle, .sunShowers         : conditionPenalty = 0.7 // Light precipitation: can still produce colour
            case .sunFlurries                                    : conditionPenalty = 0.5
            case .rain, .sleet, .flurries                        : conditionPenalty = 0.2 // Moderate precipitation
            case .wintryMix, .freezingRain                       : conditionPenalty = 0.15
            case .heavyRain, .snow, .hail                        : conditionPenalty = 0.05 // Heavy precipitation
            case .heavySnow, .blowingSnow                        : conditionPenalty = 0.05
            case .blizzard                                       : conditionPenalty = 0.02
            case .isolatedThunderstorms, .scatteredThunderstorms : conditionPenalty = 0.15 // Storms
            case .strongStorms, .thunderstorms                   : conditionPenalty = 0.05
            case .tropicalStorm                                  : conditionPenalty = 0.05 // Tropical hazards
            case .hurricane                                      : conditionPenalty = 0.02
            default                                              : conditionPenalty = 1.0
        }
        
        let visibilityScore: Double
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

        // In normal conditions low cloud blocks colour, but for cloud canvas the low cloud base IS what creates the illuminated wall, so skip the penalty in that case.
        let likelyLowCloud : Bool = cloud > 0.5 && visibilityKm < 10
        if likelyLowCloud && directional.shootingTowardSun && !isCloudCanvas {
            reasons.append("Low cloud base likely: colour burst may be above clouds")
        }

        var composite : Double = (cloudScore * 0.45) + (humidityScore * 0.30) + (visibilityScore * 0.25)
        let isRainy   : Bool   = window.contains { $0.precipitationChance > 0.4 }
        if isRainy { composite *= 0.3 }

        // Apply low cloud penalty only when NOT a cloud canvas
        if likelyLowCloud && !isCloudCanvas { composite *= 0.6 }

        // Wind bonus only if also low humidity: breezy + humid isn't better
        let windKph : Double = primary.wind.speed.converted(to: .kilometersPerHour).value
        if windKph > 20 && humidity < 0.6 {
            composite += 0.05
            reasons.append("Breezy and dry: atmosphere likely clear")
        }

        // Apply condition as a multiplier
        composite *= conditionPenalty

        // Apply humidity cap
        composite = min(composite, humidityCap)
        
        // Altitude proximity: applied last as a hard multiplier so midday hours can never score well regardless of conditions
        composite *= altitudeScore
        composite = min(1.0, max(0.0, composite))

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
            let time     : Date   = startOfDay.addingTimeInterval(minutes)
            let altitude : Double = SolarCalculator.calcSunPosition(at: coordinate, time: time).altitude
            if altitude > bestAltitude {
                bestAltitude = altitude
                bestTime     = time
            }
        }
        return bestTime
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
    
    private func calcApproximateHorizonCrossingTime(at coordinate: CLLocationCoordinate2D, startOfDay: Date, lookingForRising: Bool) -> Date? {
        let samplingIntervalSeconds : Double = 600.0   // 10 minutes
        var previousAltitude        : Double?

        var   sampleTime : Date = startOfDay
        while sampleTime < startOfDay.addingTimeInterval(86400) {
            let currentAltitude : Double = SolarCalculator.calcSunPosition(at: coordinate, time: sampleTime).altitude

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
