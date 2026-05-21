//
//  SolarCalculator.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//

import Foundation
import CoreLocation


struct SolarCalculator {
    
    nonisolated static func calcSunPosition(at coordinate: CLLocationCoordinate2D, time: Date) -> SunPosition {
        let julianDate       = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let n                = julianDate - 2451545.0

        // Mean longitude and mean anomaly (degrees)
        let meanLongitude    = (280.46 + 0.9856474 * n)
                                   .truncatingRemainder(dividingBy: 360)
        let meanAnomaly      = (357.528 + 0.9856003 * n)
                                   .truncatingRemainder(dividingBy: 360)
        let meanAnomalyRad   = meanAnomaly * .pi / 180

        // Ecliptic longitude
        let eclipticLon      = meanLongitude + 1.915 * sin(meanAnomalyRad) + 0.020 * sin(2 * meanAnomalyRad)

        // Obliquity of the ecliptic
        let obliquity        = 23.439 - 0.0000004 * n
        let obliquityRad     = obliquity    * .pi / 180
        let eclipticLonRad   = eclipticLon  * .pi / 180

        // Declination
        let sinDeclination   = sin(obliquityRad) * sin(eclipticLonRad)
        let declination      = asin(max(-1, min(1, sinDeclination)))

        // Right ascension — normalised to 0–360°
        var rightAscension   = atan2(cos(obliquityRad) * sin(eclipticLonRad), cos(eclipticLonRad)) * 180 / .pi
        if rightAscension < 0 { rightAscension += 360 }

        // IAU 1982 GMST
        let julianDate0      = floor(julianDate - 0.5) + 0.5
        let julianCenturies0 = (julianDate0 - 2451545.0) / 36525.0
        let utHours          = (julianDate - julianDate0) * 24.0

        let gmstAtMidnight   = (6.697374558 + 2400.0513369  * julianCenturies0 + 0.0000258622  * julianCenturies0 * julianCenturies0 - 1.7222e-9 * julianCenturies0 *
                                julianCenturies0 * julianCenturies0) * 15.0   // convert hours to degrees

        let greenwichMeanSiderealTime = (gmstAtMidnight + 360.98564724 * utHours / 24.0).truncatingRemainder(dividingBy: 360)

        // Local hour angle
        var localHourAngle = (greenwichMeanSiderealTime + coordinate.longitude - rightAscension).truncatingRemainder(dividingBy: 360)
        if localHourAngle < 0 { localHourAngle += 360 }

        let localHourAngleRad = localHourAngle      * .pi / 180
        let latitudeRad       = coordinate.latitude * .pi / 180

        // Altitude
        let sinAltitude       = sin(latitudeRad) * sin(declination) + cos(latitudeRad) * cos(declination) * cos(localHourAngleRad)
        let altitude          = asin(max(-1, min(1, sinAltitude))) * 180 / .pi

        // Azimuth
        let cosAzimuth        = (sin(declination) - sin(latitudeRad) * sinAltitude) / (cos(latitudeRad) * cos(asin(max(-1, min(1, sinAltitude)))))
        var azimuth           = acos(max(-1, min(1, cosAzimuth))) * 180 / .pi
        if sin(localHourAngleRad) > 0 { azimuth = 360 - azimuth }

        return SunPosition(time: time, altitude: altitude, azimuth: azimuth)
    }

    static func sunPositions(at coordinate: CLLocationCoordinate2D, from startTime: Date, to endTime: Date, stepMinutes: Int = 1) -> [SunPosition] {
        var positions:   [SunPosition] = []
        var currentTime  = startTime
        let stepInterval = TimeInterval(stepMinutes * 60)
        while currentTime <= endTime {
            positions.append(calcSunPosition(at: coordinate, time: currentTime))
            currentTime += stepInterval
        }
        return positions
    }

    static func terrainSunrise(from positions: [SunPosition], targetAltitude: Double) -> SunPosition? {
        for (index, position) in positions.enumerated().dropFirst() {
            let previous = positions[index - 1]
            if previous.altitude < targetAltitude && position.altitude >= targetAltitude {
                return position
            }
        }
        return nil
    }

    static func terrainSunset(from positions: [SunPosition], targetAltitude: Double) -> SunPosition? {
        for (index, position) in positions.enumerated().dropFirst() {
            let previous = positions[index - 1]
            if previous.altitude >= targetAltitude && position.altitude < targetAltitude {
                return position
            }
        }
        return nil
    }

    static func terrainAdjustedEphemeris(at coordinate: CLLocationCoordinate2D, on date: Date, profile: ElevationProfile) -> TerrainAdjustedEphemeris {
        let horizonAngle   = HorizonCalculator.apparentHorizonAngle(from: profile)
        let calendar       = Calendar.current
        let startOfDay     = calendar.startOfDay(for: date)
        let endOfDay       = startOfDay.addingTimeInterval(86400)

        let positions      = sunPositions(at: coordinate, from: startOfDay, to: endOfDay, stepMinutes: 1)

        let flatSunrise        = terrainSunrise(from: positions, targetAltitude: 0)
        let flatSunset         = terrainSunset( from: positions, targetAltitude: 0)
        let adjustedSunrise    = terrainSunrise(from: positions, targetAltitude: horizonAngle)
        let adjustedSunset     = terrainSunset( from: positions, targetAltitude: horizonAngle)

        let delay: TimeInterval? = flatSunrise.flatMap { flat in
            adjustedSunrise.map { terrain in
                terrain.time.timeIntervalSince(flat.time)
            }
        }
        let advance: TimeInterval? = flatSunset.flatMap { flat in
            adjustedSunset.map { terrain in
                flat.time.timeIntervalSince(terrain.time)
            }
        }

        return TerrainAdjustedEphemeris(
            flatHorizonSunrise:  flatSunrise?.time,
            terrainSunrise:      adjustedSunrise?.time,
            terrainDelay:        delay,
            flatHorizonSunset:   flatSunset?.time,
            terrainSunset:       adjustedSunset?.time,
            terrainAdvance:      advance,
            horizonAngle:        horizonAngle
        )
    }
}
