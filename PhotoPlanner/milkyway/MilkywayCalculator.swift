//
//  MilkywayCalculator.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 12.05.26.
//

import Foundation
import CoreLocation


struct MilkywayCalculator {

    // Galactic centre coordinates (J2000)
    private static let gcRA:  Double = 266.4168    // degrees (17h 45m 40s)
    private static let gcDec: Double = -29.0078    // degrees (-29° 00' 28")


    static func getMilkywayPosition(at coordinate: CLLocationCoordinate2D, time: Date, sunAltitude: Double) -> MilkywayPosition {
        let (altitude, azimuth) = equatorialToHorizontal(ra: gcRA, dec: gcDec, latitude: coordinate.latitude, longitude: coordinate.longitude, time: time)

        // Astronomical darkness requires sun below -18°
        let isAstroDark   : Bool   = sunAltitude < -18
        let isCoreVisible : Bool   = altitude > 0 && isAstroDark
        let quality       : MilkywayPosition.Quality = computeQuality(coreAltitude: altitude, isAstroDark: isAstroDark)

        return MilkywayPosition(time: time, altitude: altitude, azimuth: azimuth, isVisible: isCoreVisible, coreAltitude: altitude, quality: quality)
    }

    static func getNightTimeline(at coordinate: CLLocationCoordinate2D, on date: Date, stepMinutes: Int = 15) async -> MilkywayTimeline {
        let timeZone   : TimeZone = await Helper.fetchTimeZone(for: coordinate)
        var calendar   : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        
        let startOfDay : Date               = calendar.startOfDay(for: date)
        var slots      : [MilkywayPosition] = []
        var current    : Date               = startOfDay
        let step       : TimeInterval       = TimeInterval(stepMinutes * 60)

        while current < startOfDay + 86400 {
            let sunPos : SunPos           = Helper.calcSunPos(at: coordinate, time: current)
            let mwPos  : MilkywayPosition = getMilkywayPosition(at: coordinate, time: current, sunAltitude: sunPos.altitude)
            slots.append(mwPos)
            current += step
        }

        // Peak = highest core altitude during astronomical darkness
        let peakSlot = slots
            .filter { $0.isVisible }
            .max { $0.coreAltitude < $1.coreAltitude }

        // Shooting window = continuous block where core is visible
        let windowStart : Date? = slots.first { $0.isVisible }?.time
        let windowEnd   : Date? = slots.last  { $0.isVisible }?.time

        return MilkywayTimeline(date: date, slots: slots, peakSlot: peakSlot, windowStart: windowStart, windowEnd: windowEnd, timeZone: timeZone)
    }

    private static func computeQuality(coreAltitude: Double, isAstroDark:  Bool) -> MilkywayPosition.Quality {
        guard isAstroDark && coreAltitude > 0 else { return .notVisible }

        switch coreAltitude {
            case ..<5    : return .poor       // just above horizon, atmospheric extinction
            case 5..<15  : return .fair
            case 15..<25 : return .good
            default      : return .excellent  // high in sky, minimal extinction
        }
    }

    private static func equatorialToHorizontal(ra: Double, dec: Double, latitude: Double, longitude: Double, time: Date) -> (altitude: Double, azimuth: Double) {
        let jd       : Double = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let n        : Double = jd - 2451545.0

        // Greenwich Mean Sidereal Time (degrees)
        let c        : DateComponents = Calendar(identifier: .gregorian).dateComponents([.hour, .minute, .second], from: time)
        let utH      : Double         = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
        let gmst     : Double         = (280.46061837 + 360.98564736629 * n + 0.000387933 * (n / 36525) * (n / 36525) + utH * 15).truncatingRemainder(dividingBy: 360)

        // Local Hour Angle
        let lha      : Double = (gmst + longitude - ra).truncatingRemainder(dividingBy: 360)
        let lhaRad   : Double = lha    * .pi / 180
        let decRad   : Double = dec    * .pi / 180
        let latRad   : Double = latitude * .pi / 180

        // Altitude
        let sinAlt   : Double = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(lhaRad)
        let altitude : Double = asin(max(-1, min(1, sinAlt))) * 180 / .pi

        // Azimuth
        let cosAz    : Double = (sin(decRad) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(sinAlt)))
        var azimuth  : Double = acos(max(-1, min(1, cosAz))) * 180 / .pi
        if sin(lhaRad) > 0 { azimuth = 360 - azimuth }

        return (altitude, azimuth)
    }
}
