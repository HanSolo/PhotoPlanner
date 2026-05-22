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
        let julianDate        : Double = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let n                 : Double = julianDate - 2451545.0

        // Mean longitude and mean anomaly (degrees)
        let meanLongitude     : Double = (280.46 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let meanAnomaly       : Double = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360)
        let meanAnomalyRad    : Double = meanAnomaly * .pi / 180

        // Ecliptic longitude
        let eclipticLon       : Double = meanLongitude + 1.915 * sin(meanAnomalyRad) + 0.020 * sin(2 * meanAnomalyRad)

        // Obliquity of the ecliptic
        let obliquity         : Double = 23.439 - 0.0000004 * n
        let obliquityRad      : Double = obliquity    * .pi / 180
        let eclipticLonRad    : Double = eclipticLon  * .pi / 180

        // Declination
        let sinDeclination    : Double = sin(obliquityRad) * sin(eclipticLonRad)
        let declination       : Double = asin(max(-1, min(1, sinDeclination)))

        // Right ascension (normalised to 0...360°)
        var rightAscension    : Double = atan2(cos(obliquityRad) * sin(eclipticLonRad), cos(eclipticLonRad)) * 180 / .pi
        if rightAscension < 0 { rightAscension += 360 }

        // IAU 1982 GMST
        let julianDate0       : Double = floor(julianDate - 0.5) + 0.5
        let julianCenturies0  : Double = (julianDate0 - 2451545.0) / 36525.0
        let utHours           : Double = (julianDate - julianDate0) * 24.0

        let gmstAtMidnight    : Double = (6.697374558 + 2400.0513369  * julianCenturies0 + 0.0000258622  * julianCenturies0 * julianCenturies0 - 1.7222e-9 * julianCenturies0 *
                                         julianCenturies0 * julianCenturies0) * 15.0   // convert hours to degrees

        let greenwichMeanSiderealTime : Double = (gmstAtMidnight + 360.98564724 * utHours / 24.0).truncatingRemainder(dividingBy: 360)

        // Local hour angle
        var localHourAngle    : Double = (greenwichMeanSiderealTime + coordinate.longitude - rightAscension).truncatingRemainder(dividingBy: 360)
        if localHourAngle < 0 { localHourAngle += 360 }

        let localHourAngleRad : Double = localHourAngle * .pi / 180
        let latitudeRad       : Double = coordinate.latitude * .pi / 180

        // Altitude
        let sinAltitude       : Double = sin(latitudeRad) * sin(declination) + cos(latitudeRad) * cos(declination) * cos(localHourAngleRad)
        let altitude          : Double = asin(max(-1, min(1, sinAltitude))) * 180 / .pi

        // Azimuth
        let cosAzimuth        : Double = (sin(declination) - sin(latitudeRad) * sinAltitude) / (cos(latitudeRad) * cos(asin(max(-1, min(1, sinAltitude)))))
        var azimuth           : Double = acos(max(-1, min(1, cosAzimuth))) * 180 / .pi
        if sin(localHourAngleRad) > 0 { azimuth = 360 - azimuth }

        return SunPosition(time: time, altitude: altitude, azimuth: azimuth)
    }

    static func sunPositions(at coordinate: CLLocationCoordinate2D, from startTime: Date, to endTime: Date, stepMinutes: Int = 1) -> [SunPosition] {
        var positions    : [SunPosition] = []
        var currentTime  : Date          = startTime
        let stepInterval : TimeInterval  = TimeInterval(stepMinutes * 60)
        while currentTime <= endTime {
            positions.append(calcSunPosition(at: coordinate, time: currentTime))
            currentTime += stepInterval
        }
        return positions
    }

    static func terrainSunrise(from positions: [SunPosition], targetAltitude: Double) -> SunPosition? {
        for (index, position) in positions.enumerated().dropFirst() {
            let previous : SunPosition = positions[index - 1]
            if previous.altitude < targetAltitude && position.altitude >= targetAltitude {
                return position
            }
        }
        return nil
    }

    static func terrainSunset(from positions: [SunPosition], targetAltitude: Double) -> SunPosition? {
        for (index, position) in positions.enumerated().dropFirst() {
            let previous : SunPosition = positions[index - 1]
            if previous.altitude >= targetAltitude && position.altitude < targetAltitude {
                return position
            }
        }
        return nil
    }

    static func terrainAdjustedEphemeris(at coordinate: CLLocationCoordinate2D, on date: Date, profile: ElevationProfile) -> TerrainAdjustedEphemeris {
        let horizonAngle    : Double        = HorizonCalculator.apparentHorizonAngle(from: profile)
        let calendar        : Calendar      = Calendar.current
        let startOfDay      : Date          = calendar.startOfDay(for: date)
        let endOfDay        : Date          = startOfDay.addingTimeInterval(86400)

        let positions       : [SunPosition] = sunPositions(at: coordinate, from: startOfDay, to: endOfDay, stepMinutes: 1)

        let flatSunrise     : SunPosition?  = terrainSunrise(from: positions, targetAltitude: 0)
        let flatSunset      : SunPosition?  = terrainSunset( from: positions, targetAltitude: 0)
        let adjustedSunrise : SunPosition?  = terrainSunrise(from: positions, targetAltitude: horizonAngle)
        let adjustedSunset  : SunPosition?  = terrainSunset( from: positions, targetAltitude: horizonAngle)

        let delay : TimeInterval? = flatSunrise.flatMap { flat in
            adjustedSunrise.map { terrain in
                terrain.time.timeIntervalSince(flat.time)
            }
        }
        let advance : TimeInterval? = flatSunset.flatMap { flat in
            adjustedSunset.map { terrain in
                flat.time.timeIntervalSince(terrain.time)
            }
        }

        return TerrainAdjustedEphemeris(flatHorizonSunrise: flatSunrise?.time, terrainSunrise: adjustedSunrise?.time, terrainDelay: delay, flatHorizonSunset: flatSunset?.time,
                                        terrainSunset: adjustedSunset?.time, terrainAdvance: advance, horizonAngle: horizonAngle)
    }
}
