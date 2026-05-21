//
//  MoonCalculator.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.05.26.
//

import Foundation
import CoreLocation


struct MoonCalculator {

    static func calcMoonPosition(at coordinate: CLLocationCoordinate2D, time: Date) -> (altitude: Double, azimuth: Double) {
        let jd  : Double = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let T   : Double = (jd - 2451545.0) / 36525.0

        // Fundamental arguments (degrees)
        let L0  : Double = (218.3164477 + 481267.88123421 * T - 0.0015786  * T * T + T * T * T / 538841.0 - T * T * T * T / 65194000.0).truncatingRemainder(dividingBy: 360)
        let D   : Double = (297.8501921 + 445267.1114034 * T - 0.0018819  * T * T + T * T * T / 545868.0 - T * T * T * T / 113065000.0).truncatingRemainder(dividingBy: 360)
        let M   : Double = (357.5291092 + 35999.0502909 * T - 0.0001536   * T * T + T * T * T / 24490000.0).truncatingRemainder(dividingBy: 360)
        let Mp  : Double = (134.9633964 + 477198.8675055 * T + 0.0087414   * T * T + T * T * T / 69699.0 - T * T * T * T / 14712000.0).truncatingRemainder(dividingBy: 360)
        let F   : Double = (93.2720950  + 483202.0175233 * T - 0.0036539   * T * T - T * T * T / 3526000.0 + T * T * T * T / 863310000.0).truncatingRemainder(dividingBy: 360)

        // Convert to radians
        let Dr  : Double = D  * .pi / 180
        let Mr  : Double = M  * .pi / 180
        let Mpr : Double = Mp * .pi / 180
        let Fr  : Double = F  * .pi / 180

        // Venus and Jupiter corrections
        let A1  : Double = (119.75 + 131.849    * T).truncatingRemainder(dividingBy: 360)
        let A2  : Double = (53.09  + 479264.290 * T).truncatingRemainder(dividingBy: 360)
        let A3  : Double = (313.45 + 481266.484 * T).truncatingRemainder(dividingBy: 360)
        let A1r : Double = A1 * .pi / 180
        let A2r : Double = A2 * .pi / 180
        let A3r : Double = A3 * .pi / 180

        // E factor for Sun's anomaly terms
        let E : Double = 1.0 - 0.002516 * T - 0.0000074 * T * T

        // Longitude perturbations (units of 0.000001 degrees)
        var dLon : Double = 0
        dLon += 6288774 * sin(Mpr)
        dLon += 1274027 * sin(2*Dr - Mpr)
        dLon +=  658314 * sin(2*Dr)
        dLon +=  213618 * sin(2*Mpr)
        dLon -=  185116 * sin(Mr)  * E
        dLon -=  114332 * sin(2*Fr)
        dLon +=   58793 * sin(2*Dr - 2*Mpr)
        dLon +=   57066 * sin(2*Dr - Mr - Mpr) * E
        dLon +=   53322 * sin(2*Dr + Mpr)
        dLon +=   45758 * sin(2*Dr - Mr) * E
        dLon -=   40923 * sin(Mr - Mpr) * E
        dLon -=   34720 * sin(Dr)
        dLon -=   30383 * sin(Mr + Mpr) * E
        dLon +=   15327 * sin(2*Dr - 2*Fr)
        dLon -=   12528 * sin(Mpr + 2*Fr)
        dLon +=   10980 * sin(Mpr - 2*Fr)
        dLon +=   10675 * sin(4*Dr - Mpr)
        dLon +=   10034 * sin(3*Mpr)
        dLon +=    8548 * sin(4*Dr - 2*Mpr)
        dLon -=    7888 * sin(2*Dr + Mr - Mpr) * E
        dLon -=    6766 * sin(2*Dr + Mr) * E
        dLon -=    5163 * sin(Dr - Mpr)
        dLon +=    4987 * sin(Dr + Mr) * E
        dLon +=    4036 * sin(2*Dr - Mr + Mpr) * E
        dLon +=    3994 * sin(2*Dr + 2*Mpr)
        dLon +=    3861 * sin(4*Dr)
        dLon +=    3665 * sin(2*Dr - 3*Mpr)
        dLon -=    2689 * sin(Mr - 2*Mpr) * E
        dLon -=    2602 * sin(2*Dr - Mpr + 2*Fr)
        dLon +=    2390 * sin(2*Dr - Mr - 2*Mpr) * E
        dLon -=    2348 * sin(Dr + Mpr)
        dLon +=    2236 * sin(2*Dr - 2*Mr) * E * E
        dLon -=    2120 * sin(Mr + 2*Mpr) * E
        dLon -=    2069 * sin(2*Mr) * E * E
        dLon +=    2048 * sin(2*Dr - 2*Mr - Mpr) * E * E
        dLon -=    1773 * sin(2*Dr + Mpr - 2*Fr)
        dLon -=    1595 * sin(2*Dr + 2*Fr)
        dLon +=    1215 * sin(4*Dr - Mr - Mpr) * E
        dLon -=    1110 * sin(2*Mpr + 2*Fr)
        dLon -=     892 * sin(3*Dr - Mpr)
        dLon -=     810 * sin(2*Dr + Mr + Mpr) * E
        dLon +=     759 * sin(4*Dr - Mr - 2*Mpr) * E
        dLon -=     713 * sin(2*Mr - Mpr) * E * E
        dLon -=     700 * sin(2*Dr + 2*Mr - Mpr) * E * E
        dLon +=     691 * sin(2*Dr + Mr - 2*Mpr) * E
        dLon +=     596 * sin(2*Dr - Mr - 2*Fr) * E
        dLon +=     549 * sin(4*Dr + Mpr)
        dLon +=     537 * sin(4*Mpr)
        dLon +=     520 * sin(4*Dr - Mr) * E
        dLon -=     487 * sin(Dr - 2*Mpr)
        dLon -=     399 * sin(2*Dr + Mr - 2*Fr) * E
        dLon -=     381 * sin(2*Mpr - 2*Fr)
        dLon +=     351 * sin(Dr + Mr + Mpr) * E
        dLon -=     340 * sin(3*Dr - 2*Mpr)
        dLon +=     330 * sin(4*Dr - 3*Mpr)
        dLon +=     327 * sin(2*Dr - Mr + 2*Mpr) * E
        dLon -=     323 * sin(2*Mr + Mpr) * E * E
        dLon +=     299 * sin(Dr + Mr - Mpr) * E
        dLon +=     294 * sin(2*Dr + 3*Mpr)

        // Additional corrections
        dLon += 3958 * sin(A1r)
        dLon += 1962 * sin(L0 * .pi / 180 - Fr)
        dLon +=  318 * sin(A2r)

        // Latitude perturbations (units of 0.000001 degrees)
        var dLat : Double = 0
        dLat += 5128122 * sin(Fr)
        dLat +=  280602 * sin(Mpr + Fr)
        dLat +=  277693 * sin(Mpr - Fr)
        dLat +=  173237 * sin(2*Dr - Fr)
        dLat +=   55413 * sin(2*Dr - Mpr + Fr)
        dLat +=   46271 * sin(2*Dr - Mpr - Fr)
        dLat +=   32573 * sin(2*Dr + Fr)
        dLat +=   17198 * sin(2*Mpr + Fr)
        dLat +=    9266 * sin(2*Dr + Mpr - Fr)
        dLat +=    8822 * sin(2*Mpr - Fr)
        dLat +=    8216 * sin(2*Dr - Mr - Fr) * E
        dLat +=    4324 * sin(2*Dr - 2*Mpr - Fr)
        dLat +=    4200 * sin(2*Dr + Mpr + Fr)
        dLat -=    3359 * sin(2*Dr + Mr - Fr) * E
        dLat +=    2463 * sin(2*Dr - Mr + Mpr - Fr) * E
        dLat +=    2211 * sin(2*Dr - Mr - Fr) * E
        dLat +=    2065 * sin(2*Dr - Mr + Mpr + Fr) * E
        dLat -=    1870 * sin(Mr - Mpr - Fr) * E
        dLat +=    1828 * sin(4*Dr - Mpr - Fr)
        dLat -=    1794 * sin(Mr + Fr) * E
        dLat -=    1749 * sin(3*Fr)
        dLat -=    1565 * sin(Mr - Mpr + Fr) * E
        dLat -=    1491 * sin(Dr + Fr)
        dLat -=    1475 * sin(Mr + Mpr + Fr) * E
        dLat -=    1410 * sin(Mr + Mpr - Fr) * E
        dLat -=    1344 * sin(Mr - Fr) * E
        dLat -=    1335 * sin(Dr - Fr)
        dLat +=    1107 * sin(3*Mpr + Fr)
        dLat +=    1021 * sin(4*Dr - Fr)
        dLat +=     833 * sin(4*Dr - Mpr + Fr)
        dLat +=     777 * sin(Mpr - 3*Fr)
        dLat +=     671 * sin(4*Dr - 2*Mpr + Fr)
        dLat +=     607 * sin(2*Dr - 3*Fr)
        dLat +=     596 * sin(2*Dr + 2*Mpr - Fr)
        dLat +=     491 * sin(2*Dr - Mr + Mpr - Fr) * E
        dLat -=     451 * sin(2*Dr - 2*Mpr + Fr)
        dLat +=     439 * sin(3*Mpr - Fr)
        dLat +=     422 * sin(2*Dr + 2*Mpr + Fr)
        dLat +=     421 * sin(2*Dr - 3*Mpr - Fr)
        dLat -=     366 * sin(2*Dr + Mr - Mpr + Fr) * E
        dLat -=     351 * sin(2*Dr + Mr + Fr) * E
        dLat +=     331 * sin(4*Dr + Fr)
        dLat +=     315 * sin(2*Dr - Mr + Mpr + Fr) * E
        dLat +=     302 * sin(2*Dr - 2*Mr - Fr) * E * E
        dLat -=     283 * sin(Mpr + 3*Fr)
        dLat -=     229 * sin(2*Dr + Mr + Mpr - Fr) * E
        dLat +=     223 * sin(Dr + Mr - Fr) * E
        dLat +=     223 * sin(Dr + Mr + Fr) * E
        dLat -=     220 * sin(Mr - 2*Mpr - Fr) * E
        dLat -=     220 * sin(2*Dr + Mr - Mpr - Fr) * E
        dLat -=     185 * sin(Dr + Mpr + Fr)
        dLat +=     181 * sin(2*Dr - Mr - 2*Mpr - Fr) * E
        dLat -=     177 * sin(Mr + 2*Mpr + Fr) * E
        dLat +=     176 * sin(4*Dr - 2*Mpr - Fr)
        dLat +=     166 * sin(4*Dr - Mr - Mpr - Fr) * E
        dLat -=     164 * sin(Dr + Mpr - Fr)
        dLat +=     132 * sin(4*Dr + Mpr - Fr)
        dLat -=     119 * sin(Dr - Mpr - Fr)
        dLat +=     115 * sin(4*Dr - Mr - Fr) * E
        dLat +=     107 * sin(2*Dr - 2*Mr + Fr) * E * E

        // Additional latitude corrections
        dLat -= 2235 * sin(L0 * .pi / 180)
        dLat +=  382 * sin(A3r)
        dLat +=  175 * sin(A1r - Fr)
        dLat +=  175 * sin(A1r + Fr)
        dLat +=  127 * sin(L0 * .pi / 180 - Mpr)
        dLat -=  115 * sin(L0 * .pi / 180 + Mpr)

        // Convert from 0.000001 degree units to degrees
        let lambda     : Double = (L0 + dLon / 1000000.0).truncatingRemainder(dividingBy: 360)
        let beta       : Double = dLat / 1000000.0

        // Convert ecliptic to equatorial
        let epsilon    : Double = 23.439 - 0.013 * T
        let epsilonRad : Double = epsilon * .pi / 180
        let lambdaRad  : Double = lambda  * .pi / 180
        let betaRad    : Double = beta    * .pi / 180

        let sinDec     : Double = sin(betaRad) * cos(epsilonRad) + cos(betaRad) * sin(epsilonRad) * sin(lambdaRad)
        let dec        : Double = asin(max(-1, min(1, sinDec)))

        // RA normalized to 0–360
        var raNorm     : Double = atan2(sin(lambdaRad) * cos(epsilonRad) - tan(betaRad) * sin(epsilonRad), cos(lambdaRad)) * 180 / .pi
        if raNorm < 0 { raNorm += 360 }

        // IAU 1982 GMST
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

        // Altitude
        let sinAlt     : Double = sin(latRad) * sin(dec) + cos(latRad) * cos(dec) * cos(lhaRad)
        let altitude   : Double = asin(max(-1, min(1, sinAlt))) * 180 / .pi

        // Azimuth
        let cosAz      : Double = (sin(dec) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(max(-1, min(1, sinAlt)))))
        var azimuth    : Double = acos(max(-1, min(1, cosAz))) * 180 / .pi
        if sin(lhaRad) > 0 { azimuth = 360 - azimuth }

        return (altitude, azimuth)
    }
    
    static func calcMoonPhase(at coordinate: CLLocationCoordinate2D, time: Date, timeZone: TimeZone) -> MoonPhase {
        let jd          : Double  = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let T           : Double  = (jd - 2451545.0) / 36525.0

        // Sun's mean anomaly
        let Ms          : Double  = (357.5291092 + 35999.0502909 * T).truncatingRemainder(dividingBy: 360)
        let msRad       : Double  = Ms * .pi / 180

        // Moon's mean anomaly
        let Mm           : Double = (134.9633964 + 477198.8675055 * T).truncatingRemainder(dividingBy: 360)
        let mmRad        : Double = Mm * .pi / 180

        // Moon's elongation from sun
        let D            : Double = (297.8501921 + 445267.1114034 * T).truncatingRemainder(dividingBy: 360)
        let dRad         : Double = D * .pi / 180

        // Phase angle (0 = new, 180 = full)
        let phaseAngle   : Double = 180 - D - 6.289 * sin(mmRad) + 2.100 * sin(msRad) - 1.274 * sin(2 * dRad - mmRad) - 0.658 * sin(2 * dRad) - 0.214 * sin(2 * mmRad) - 0.110 * sin(dRad)

        let normalised   : Double = phaseAngle.truncatingRemainder(dividingBy: 360)
        let angle        : Double = normalised < 0 ? normalised + 360 : normalised

        // Illumination fraction
        let illumination : Double = (1 - cos(angle * .pi / 180)) / 2

        // Waxing if angle increasing (D increasing)
        let isWaxing     : Bool   = angle < 180

        // Phase name from illumination + waxing/waning
        let phaseName: MoonPhase.PhaseName
        switch angle {
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

        return MoonPhase(date: time, illumination: illumination, phaseAngle: angle, phaseName: phaseName, isWaxing: isWaxing,
                         riseTime: riseTime, setTime: setTime, altitude: altitude, azimuth: azimuth, timeZone: timeZone)
    }

    static func calcMoonRiseAndMoonSet(at coordinate: CLLocationCoordinate2D, on date: Date, timeZone: TimeZone) -> (moonRise: Date?, moonSet: Date?) {
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

    private static func interpolateCrossing(t0: Date, a0: Double, t1: Date, a1: Double) -> Date {
        let fraction : Double = -a0 / (a1 - a0)
        return t0.addingTimeInterval(fraction * t1.timeIntervalSince(t0))
    }
}
