//
//  MoonCalculator.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.05.26.
//

import Foundation
import CoreLocation


struct MoonCalculator {

    // MARK: - Moon position (Jean Meeus simplified)

    static func moonPosition(at coordinate: CLLocationCoordinate2D, time: Date) -> (altitude: Double, azimuth: Double) {
        let jd     : Double = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let T      : Double = (jd - 2451545.0) / 36525.0   // Julian centuries

        // Moon's mean longitude
        let L0     : Double = (218.3164477 + 481267.88123421 * T).truncatingRemainder(dividingBy: 360)

        // Moon's mean anomaly
        let M          : Double = (134.9633964 + 477198.8675055 * T).truncatingRemainder(dividingBy: 360)
        let mRad       : Double = M * .pi / 180

        // Moon's mean elongation
        let D          : Double = (297.8501921 + 445267.1114034 * T).truncatingRemainder(dividingBy: 360)
        let dRad       : Double = D * .pi / 180

        // Sun's mean anomaly
        let Ms         : Double = (357.5291092 + 35999.0502909 * T).truncatingRemainder(dividingBy: 360)
        let msRad      : Double = Ms * .pi / 180

        // Longitude correction
        let dLon       : Double = 6.289 * sin(mRad) - 1.274 * sin(2 * dRad - mRad) + 0.658 * sin(2 * dRad) - 0.214 * sin(2 * mRad) - 0.186 * sin(msRad) - 0.114 * sin(2 * (D * .pi / 180))
        let lambda     : Double = (L0 + dLon).truncatingRemainder(dividingBy: 360)

        // Latitude correction
        let F          : Double = (93.2720950 + 483202.0175233 * T).truncatingRemainder(dividingBy: 360)
        let beta       : Double = 5.128 * sin(F * .pi / 180)

        // Convert ecliptic to equatorial
        let epsilon    : Double = 23.439 - 0.013 * T
        let epsilonRad : Double = epsilon * .pi / 180
        let lambdaRad  : Double = lambda  * .pi / 180
        let betaRad    : Double = beta    * .pi / 180

        let sinDec     : Double = sin(betaRad) * cos(epsilonRad) + cos(betaRad) * sin(epsilonRad) * sin(lambdaRad)
        let dec        : Double = asin(max(-1, min(1, sinDec)))
        let ra         : Double = atan2(sin(lambdaRad) * cos(epsilonRad) - tan(betaRad) * sin(epsilonRad), cos(lambdaRad)) * 180 / .pi

        // Hour angle
        let c          : DateComponents = Calendar(identifier: .gregorian).dateComponents([.hour, .minute, .second], from: time)
        let utH        : Double         = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
        let n          : Double         = jd - 2451545.0
        let gmst       : Double         = (280.46061837 + 360.98564736629 * n + utH * 15).truncatingRemainder(dividingBy: 360)
        let lha        : Double         = (gmst + coordinate.longitude - ra).truncatingRemainder(dividingBy: 360)
        let lhaRad     : Double         = lha * .pi / 180
        let latRad     : Double         = coordinate.latitude * .pi / 180

        // Altitude and azimuth
        let sinAlt     : Double = sin(latRad) * sin(dec) + cos(latRad) * cos(dec) * cos(lhaRad)
        let altitude   : Double = asin(max(-1, min(1, sinAlt))) * 180 / .pi

        let cosAz      : Double = (sin(dec) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(max(-1, min(1, sinAlt)))))
        var azimuth    : Double = acos(max(-1, min(1, cosAz))) * 180 / .pi
        if sin(lhaRad) > 0 { azimuth = 360 - azimuth }

        return (altitude, azimuth)
    }

    
    static func phase(at coordinate: CLLocationCoordinate2D, time: Date, timeZone: TimeZone) -> MoonPhase {
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
        let (riseTime, setTime) = riseSet(at: coordinate, on: time, timeZone: timeZone)

        // Current position
        let (altitude, azimuth) = moonPosition(at: coordinate, time: time)

        return MoonPhase(date: time, illumination: illumination, phaseAngle: angle, phaseName: phaseName, isWaxing: isWaxing,
                         riseTime: riseTime, setTime: setTime, altitude: altitude, azimuth: azimuth, timeZone: timeZone)
    }

    // MARK: - Rise and set times

    static func riseSet(at coordinate: CLLocationCoordinate2D, on date: Date, timeZone: TimeZone) -> (rise: Date?, set: Date?) {
        var calendar   : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        
        let startOfDay : Date     = calendar.startOfDay(for: date)

        // Sample every 10 min across 48h to catch edge cases
        // where moon rises/sets close to midnight
        let samples: [(Date, Double)] = stride(from: 0.0, through: 48 * 3600, by: 600).map { offset in
            let t   : Date   = startOfDay.addingTimeInterval(offset)
            let alt : Double = moonPosition(at: coordinate, time: t).altitude
            return (t, alt)
        }

        var riseTime : Date?
        var setTime  : Date?
 
        for i in 1..<samples.count {
            let (prevTime, prevAlt) = samples[i - 1]
            let (currTime, currAlt) = samples[i]

            // Rising crossing
            if prevAlt < 0 && currAlt >= 0 && riseTime == nil {
                riseTime = interpolateCrossing(t0: prevTime, a0: prevAlt, t1: currTime, a1: currAlt)
            }

            // Setting crossing
            if prevAlt >= 0 && currAlt < 0 && setTime == nil {
                setTime = interpolateCrossing(t0: prevTime, a0: prevAlt, t1: currTime, a1: currAlt)
            }

            if riseTime != nil && setTime != nil { break }
        }

        return (riseTime, setTime)
    }

    private static func interpolateCrossing(t0: Date, a0: Double, t1: Date, a1: Double) -> Date {
        let fraction : Double = -a0 / (a1 - a0)
        return t0.addingTimeInterval(fraction * t1.timeIntervalSince(t0))
    }
}
