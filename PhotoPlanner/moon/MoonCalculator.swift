//
//  MoonCalculator.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.05.26.
//

import Foundation
import CoreLocation


struct MoonCalculator {
        
    nonisolated static func calcMoonPosition(at coordinate: CLLocationCoordinate2D, time: Date) -> (altitude: Double, azimuth: Double) {
            let julianDate          : Double = time.timeIntervalSince1970 / 86400.0 + 2440587.5
            let T                   : Double = (julianDate - 2451545.0) / 36525.0

            // Fundamental arguments (degrees)
            let meanLongitude       : Double = (218.3164477 + 481267.88123421 * T - 0.0015786  * T * T + T * T * T / 538841.0 - T * T * T * T / 65194000.0)
                                               .truncatingRemainder(dividingBy: 360)

            let elongation          : Double = (297.8501921 + 445267.1114034 * T - 0.0018819  * T * T + T * T * T / 545868.0 - T * T * T * T / 113065000.0)
                                               .truncatingRemainder(dividingBy: 360)

            let sunAnomaly          : Double = (357.5291092 + 35999.0502909 * T - 0.0001536   * T * T + T * T * T / 24490000.0)
                                               .truncatingRemainder(dividingBy: 360)

            let moonAnomaly         : Double = (134.9633964 + 477198.8675055 * T + 0.0087414   * T * T + T * T * T / 69699.0 - T * T * T * T / 14712000.0)
                                               .truncatingRemainder(dividingBy: 360)

            let latitudeArg         : Double = (93.2720950  + 483202.0175233 * T - 0.0036539   * T * T - T * T * T / 3526000.0 + T * T * T * T / 863310000.0)
                                               .truncatingRemainder(dividingBy: 360)

            let elongationRad       : Double = elongation  * .pi / 180
            let sunAnomalyRad       : Double = sunAnomaly  * .pi / 180
            let moonAnomalyRad      : Double = moonAnomaly * .pi / 180
            let latitudeArgRad      : Double = latitudeArg * .pi / 180

            // Venus and Jupiter corrections
            let venusCorrection     : Double = (119.75 + 131.849    * T).truncatingRemainder(dividingBy: 360)
            let jupiterCorrection   : Double = (53.09  + 479264.290 * T).truncatingRemainder(dividingBy: 360)
            let flatteningCorr      : Double = (313.45 + 481266.484 * T).truncatingRemainder(dividingBy: 360)
            let venusCorrRad        : Double = venusCorrection   * .pi / 180
            let jupiterCorrRad      : Double = jupiterCorrection * .pi / 180
            let flatteningCorrRad   : Double = flatteningCorr    * .pi / 180

            // Earth eccentricity factor
            let eccentricity        : Double = 1.0 - 0.002516 * T - 0.0000074 * T * T

            // Longitude perturbations (0.000001 degree units) from Meeus Table 47.A
            var longitudeCorrection : Double = 0
            longitudeCorrection += 6288774 * sin(moonAnomalyRad)
            longitudeCorrection += 1274027 * sin(2 * elongationRad - moonAnomalyRad)
            longitudeCorrection +=  658314 * sin(2 * elongationRad)
            longitudeCorrection +=  213618 * sin(2 * moonAnomalyRad)
            longitudeCorrection -=  185116 * sin(sunAnomalyRad)  * eccentricity
            longitudeCorrection -=  114332 * sin(2 * latitudeArgRad)
            longitudeCorrection +=   58793 * sin(2 * elongationRad - 2*moonAnomalyRad)
            longitudeCorrection +=   57066 * sin(2 * elongationRad - sunAnomalyRad - moonAnomalyRad) * eccentricity
            longitudeCorrection +=   53322 * sin(2 * elongationRad + moonAnomalyRad)
            longitudeCorrection +=   45758 * sin(2 * elongationRad - sunAnomalyRad) * eccentricity
            longitudeCorrection -=   40923 * sin(sunAnomalyRad - moonAnomalyRad) * eccentricity
            longitudeCorrection -=   34720 * sin(elongationRad)
            longitudeCorrection -=   30383 * sin(sunAnomalyRad + moonAnomalyRad) * eccentricity
            longitudeCorrection +=   15327 * sin(2 * elongationRad - 2 * latitudeArgRad)
            longitudeCorrection -=   12528 * sin(moonAnomalyRad + 2 * latitudeArgRad)
            longitudeCorrection +=   10980 * sin(moonAnomalyRad - 2 * latitudeArgRad)
            longitudeCorrection +=   10675 * sin(4 * elongationRad - moonAnomalyRad)
            longitudeCorrection +=   10034 * sin(3 * moonAnomalyRad)
            longitudeCorrection +=    8548 * sin(4 * elongationRad - 2 * moonAnomalyRad)
            longitudeCorrection -=    7888 * sin(2 * elongationRad + sunAnomalyRad - moonAnomalyRad) * eccentricity
            longitudeCorrection -=    6766 * sin(2 * elongationRad + sunAnomalyRad) * eccentricity
            longitudeCorrection -=    5163 * sin(elongationRad - moonAnomalyRad)
            longitudeCorrection +=    4987 * sin(elongationRad + sunAnomalyRad) * eccentricity
            longitudeCorrection +=    4036 * sin(2 * elongationRad - sunAnomalyRad + moonAnomalyRad) * eccentricity
            longitudeCorrection +=    3994 * sin(2 * elongationRad + 2 * moonAnomalyRad)
            longitudeCorrection +=    3861 * sin(4 * elongationRad)
            longitudeCorrection +=    3665 * sin(2 * elongationRad - 3 * moonAnomalyRad)
            longitudeCorrection -=    2689 * sin(sunAnomalyRad - 2 * moonAnomalyRad) * eccentricity
            longitudeCorrection +=    2390 * sin(2 * elongationRad - sunAnomalyRad - 2 * moonAnomalyRad) * eccentricity
            longitudeCorrection -=    2348 * sin(elongationRad + moonAnomalyRad)
            longitudeCorrection +=    2236 * sin(2 * elongationRad - 2 * sunAnomalyRad) * eccentricity * eccentricity
            longitudeCorrection -=    2120 * sin(sunAnomalyRad + 2 * moonAnomalyRad) * eccentricity
            longitudeCorrection -=    2069 * sin(2 * sunAnomalyRad) * eccentricity * eccentricity
            longitudeCorrection +=    2048 * sin(2 * elongationRad - 2 * sunAnomalyRad - moonAnomalyRad) * eccentricity * eccentricity
            longitudeCorrection -=    1773 * sin(2 * elongationRad + moonAnomalyRad - 2 * latitudeArgRad)
            longitudeCorrection -=    1595 * sin(2 * elongationRad + 2 * latitudeArgRad)
            longitudeCorrection +=    1215 * sin(4 * elongationRad - sunAnomalyRad - moonAnomalyRad) * eccentricity
            longitudeCorrection -=    1110 * sin(2 * moonAnomalyRad + 2 * latitudeArgRad)
            longitudeCorrection +=     759 * sin(4 * elongationRad - sunAnomalyRad - 2 * moonAnomalyRad) * eccentricity
            longitudeCorrection -=     713 * sin(2 * sunAnomalyRad - moonAnomalyRad) * eccentricity * eccentricity
            longitudeCorrection +=     691 * sin(2 * elongationRad + sunAnomalyRad - 2 * moonAnomalyRad) * eccentricity
            longitudeCorrection +=     549 * sin(4 * elongationRad + moonAnomalyRad)
            longitudeCorrection +=     537 * sin(4 * moonAnomalyRad)
            longitudeCorrection +=     520 * sin(4 * elongationRad - sunAnomalyRad) * eccentricity
            longitudeCorrection -=     487 * sin(elongationRad - 2 * moonAnomalyRad)
            longitudeCorrection +=     294 * sin(2 * elongationRad + 3 * moonAnomalyRad)

            // Additional longitude corrections
            longitudeCorrection += 3958 * sin(venusCorrRad)
            longitudeCorrection += 1962 * sin(meanLongitude * .pi / 180 - latitudeArgRad)
            longitudeCorrection +=  318 * sin(jupiterCorrRad)

            // Latitude perturbations (0.000001 degree units)
            var latitudeCorrection : Double = 0
            latitudeCorrection += 5128122 * sin(latitudeArgRad)
            latitudeCorrection +=  280602 * sin(moonAnomalyRad + latitudeArgRad)
            latitudeCorrection +=  277693 * sin(moonAnomalyRad - latitudeArgRad)
            latitudeCorrection +=  173237 * sin(2 * elongationRad - latitudeArgRad)
            latitudeCorrection +=   55413 * sin(2 * elongationRad - moonAnomalyRad + latitudeArgRad)
            latitudeCorrection +=   46271 * sin(2 * elongationRad - moonAnomalyRad - latitudeArgRad)
            latitudeCorrection +=   32573 * sin(2 * elongationRad + latitudeArgRad)
            latitudeCorrection +=   17198 * sin(2 * moonAnomalyRad + latitudeArgRad)
            latitudeCorrection +=    9266 * sin(2 * elongationRad + moonAnomalyRad - latitudeArgRad)
            latitudeCorrection +=    8822 * sin(2 * moonAnomalyRad - latitudeArgRad)
            latitudeCorrection +=    8216 * sin(2 * elongationRad - sunAnomalyRad - latitudeArgRad) * eccentricity
            latitudeCorrection +=    4324 * sin(2 * elongationRad - 2*moonAnomalyRad - latitudeArgRad)
            latitudeCorrection +=    4200 * sin(2 * elongationRad + moonAnomalyRad + latitudeArgRad)
            latitudeCorrection -=    3359 * sin(2 * elongationRad + sunAnomalyRad - latitudeArgRad) * eccentricity
            latitudeCorrection +=    2463 * sin(2 * elongationRad - sunAnomalyRad + moonAnomalyRad - latitudeArgRad) * eccentricity
            latitudeCorrection +=    2211 * sin(2 * elongationRad - sunAnomalyRad - latitudeArgRad) * eccentricity
            latitudeCorrection +=    2065 * sin(2 * elongationRad - sunAnomalyRad + moonAnomalyRad + latitudeArgRad) * eccentricity
            latitudeCorrection -=    1870 * sin(sunAnomalyRad - moonAnomalyRad - latitudeArgRad) * eccentricity
            latitudeCorrection +=    1828 * sin(4 * elongationRad - moonAnomalyRad - latitudeArgRad)
            latitudeCorrection -=    1794 * sin(sunAnomalyRad + latitudeArgRad) * eccentricity
            latitudeCorrection -=    1749 * sin(3 * latitudeArgRad)
            latitudeCorrection -=    1565 * sin(sunAnomalyRad - moonAnomalyRad + latitudeArgRad) * eccentricity
            latitudeCorrection -=    1491 * sin(elongationRad + latitudeArgRad)
            latitudeCorrection -=    1475 * sin(sunAnomalyRad + moonAnomalyRad + latitudeArgRad) * eccentricity
            latitudeCorrection -=    1410 * sin(sunAnomalyRad + moonAnomalyRad - latitudeArgRad) * eccentricity
            latitudeCorrection -=    1344 * sin(sunAnomalyRad - latitudeArgRad) * eccentricity
            latitudeCorrection -=    1335 * sin(elongationRad - latitudeArgRad)
            latitudeCorrection +=    1107 * sin(3 * moonAnomalyRad + latitudeArgRad)
            latitudeCorrection +=    1021 * sin(4 * elongationRad - latitudeArgRad)
            latitudeCorrection +=     833 * sin(4 * elongationRad - moonAnomalyRad + latitudeArgRad)
            latitudeCorrection +=     777 * sin(moonAnomalyRad - 3 * latitudeArgRad)
            latitudeCorrection +=     671 * sin(4 * elongationRad - 2 * moonAnomalyRad + latitudeArgRad)
            latitudeCorrection +=     607 * sin(2 * elongationRad - 3 * latitudeArgRad)
            latitudeCorrection -=     451 * sin(2 * elongationRad - 2 * moonAnomalyRad + latitudeArgRad)

            // Additional latitude corrections
            latitudeCorrection -= 2235 * sin(meanLongitude * .pi / 180)
            latitudeCorrection +=  382 * sin(flatteningCorrRad)
            latitudeCorrection +=  175 * sin(venusCorrRad - latitudeArgRad)
            latitudeCorrection +=  175 * sin(venusCorrRad + latitudeArgRad)
            latitudeCorrection +=  127 * sin(meanLongitude * .pi / 180 - moonAnomalyRad)
            latitudeCorrection -=  115 * sin(meanLongitude * .pi / 180 + moonAnomalyRad)

            // Convert to degrees
            let eclipticLongitude : Double = (meanLongitude + longitudeCorrection / 1000000.0).truncatingRemainder(dividingBy: 360)
            let eclipticLatitude  : Double = latitudeCorrection / 1000000.0

            // Convert ecliptic to equatorial coordinates
            let obliquity         : Double = 23.439 - 0.013 * T
            let obliquityRad      : Double = obliquity         * .pi / 180
            let eclipticLonRad    : Double = eclipticLongitude * .pi / 180
            let eclipticLatRad    : Double = eclipticLatitude  * .pi / 180

            let sinDeclination    : Double = sin(eclipticLatRad) * cos(obliquityRad) + cos(eclipticLatRad) * sin(obliquityRad) * sin(eclipticLonRad)
            let declination       : Double = asin(max(-1, min(1, sinDeclination)))

            // Right ascension normalised to 0-360
            var rightAscension    : Double = atan2(sin(eclipticLonRad) * cos(obliquityRad) - tan(eclipticLatRad) * sin(obliquityRad), cos(eclipticLonRad)) * 180 / .pi
            if rightAscension < 0 { rightAscension += 360 }

            // IAU 1982 GMST (utHours derived from JD, not from Calendar)
            let julianDate0       : Double = floor(julianDate - 0.5) + 0.5
            let julianCenturies0  : Double = (julianDate0 - 2451545.0) / 36525.0
            let utHours           : Double = (julianDate - julianDate0) * 24.0

            let gmstAtMidnight    : Double = (6.697374558 + 2400.0513369  * julianCenturies0 + 0.0000258622  * julianCenturies0 * julianCenturies0 - 1.7222e-9 * julianCenturies0
                                              * julianCenturies0 * julianCenturies0) * 15.0

            let greenwichMeanSiderealTime : Double = (gmstAtMidnight + 360.98564724 * utHours / 24.0).truncatingRemainder(dividingBy: 360)

            var localHourAngle    : Double = (greenwichMeanSiderealTime + coordinate.longitude - rightAscension).truncatingRemainder(dividingBy: 360)
            if localHourAngle < 0 { localHourAngle += 360 }

            let localHourAngleRad : Double = localHourAngle      * .pi / 180
            let latitudeRad       : Double = coordinate.latitude * .pi / 180

            // Altitude
            let sinAltitude       : Double = sin(latitudeRad) * sin(declination) + cos(latitudeRad) * cos(declination) * cos(localHourAngleRad)
            let altitude          : Double = asin(max(-1, min(1, sinAltitude))) * 180 / .pi

            // Azimuth
            let cosAzimuth        : Double = (sin(declination) - sin(latitudeRad) * sinAltitude) / (cos(latitudeRad) * cos(asin(max(-1, min(1, sinAltitude)))))
            var azimuth           : Double = acos(max(-1, min(1, cosAzimuth))) * 180 / .pi
            if sin(localHourAngleRad) > 0 { azimuth = 360 - azimuth }

            return (altitude, azimuth)
        }
    
    nonisolated static func calcMoonPhase(at coordinate: CLLocationCoordinate2D, time: Date, timeZone: TimeZone) -> MoonPhase {
        let jd           : Double = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let T            : Double = (jd - 2451545.0) / 36525.0

        // Sun's mean anomaly
        let Ms           : Double = (357.5291092 + 35999.0502909  * T).truncatingRemainder(dividingBy: 360)
        let msRad        : Double = Ms * .pi / 180

        // Moon's mean anomaly
        let Mm           : Double = (134.9633964 + 477198.8675055 * T).truncatingRemainder(dividingBy: 360)
        let mmRad        : Double = Mm * .pi / 180

        // Moon's elongation from sun
        let D            : Double = (297.8501921 + 445267.1114034 * T).truncatingRemainder(dividingBy: 360)
        let dRad         : Double = D * .pi / 180

        // Normalise elongation to 0...360 (this is the primary value used for phase name, isWaxing and illumination)
        var normalisedD  : Double = D.truncatingRemainder(dividingBy: 360)
        if normalisedD < 0 { normalisedD += 360 }

        // Illumination, derived directly from elongation with small correction terms for accuracy (~1%)
        let correctedD   : Double = normalisedD + 6.289 * sin(mmRad) - 2.100 * sin(msRad) + 1.274 * sin(2 * dRad - mmRad) + 0.658 * sin(2 * dRad) + 0.214 * sin(2 * mmRad) + 0.110 * sin(dRad)

        let illumination : Double = (1 - cos(correctedD * .pi / 180)) / 2

        // Phase name and waxing/waning from normalised elongation
        let isWaxing : Bool = normalisedD < 180

        let phaseName: MoonPhase.PhaseName
            switch normalisedD {
            case 0..<10, 350..<360 : phaseName = .newMoon
            case 10..<80           : phaseName = .waxingCrescent
            case 80..<100          : phaseName = .firstQuarter
            case 100..<170         : phaseName = .waxingGibbous
            case 170..<190         : phaseName = .fullMoon
            case 190..<260         : phaseName = .waningGibbous
            case 260..<280         : phaseName = .lastQuarter
            default                : phaseName = .waningCrescent
        }

        // Rise and set times
        let (riseTime, setTime) = calcMoonRiseAndMoonSet(at: coordinate, on: time, timeZone: timeZone)

        // Current position
        let (altitude, azimuth) = calcMoonPosition(at: coordinate, time: time)

        return MoonPhase(date: time, illumination: illumination, phaseAngle: normalisedD,
                         phaseName: phaseName, isWaxing: isWaxing, riseTime: riseTime,
                         setTime: setTime, altitude: altitude, azimuth: azimuth, timeZone: timeZone)
    }

    nonisolated static func calcMoonRiseAndMoonSet(at coordinate: CLLocationCoordinate2D, on date: Date, timeZone: TimeZone) -> (moonRise: Date?, moonSet: Date?) {
        var calendar      = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay    = calendar.startOfDay(for: date)

        let samples: [(Date, Double)] = stride(
            from: 0.0, through: 86400, by: 600
        ).map { offset in
            let t   = startOfDay.addingTimeInterval(offset)
            let alt = calcMoonPosition(at: coordinate, time: t).altitude
            return (t, alt)
        }

        var riseTime: Date?
        var setTime:  Date?

        for i in 1..<samples.count {
            let (prevTime, prevAlt) = samples[i - 1]
            let (currTime, currAlt) = samples[i]

            if riseTime == nil && prevAlt < 0 && currAlt >= 0 {
                riseTime = interpolateCrossing(
                    t0: prevTime, a0: prevAlt,
                    t1: currTime, a1: currAlt
                )
            }

            if setTime == nil && prevAlt >= 0 && currAlt < 0 {
                setTime = interpolateCrossing(
                    t0: prevTime, a0: prevAlt,
                    t1: currTime, a1: currAlt
                )
            }
        }

        return (riseTime, setTime)
    }

    nonisolated private static func interpolateCrossing(t0: Date, a0: Double, t1: Date, a1: Double) -> Date {
        let fraction : Double = -a0 / (a1 - a0)
        return t0.addingTimeInterval(fraction * t1.timeIntervalSince(t0))
    }
}
