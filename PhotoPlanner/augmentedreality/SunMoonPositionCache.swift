//
//  CelestialPositionCache.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 24.05.26.
//

import Foundation
import CoreLocation


actor SunMoonPositionCache {
    private var sunPositions     : [CachedSunMoonPosition] = []
    private var moonPositions    : [CachedSunMoonPosition] = []

    private var cachedCoordinate : CLLocationCoordinate2D?
    private var cachedDate       : Date?
    private(set) var isReady     : Bool                      = false

    
    // Pre-computes sun and moon positions every stepSeconds 24 hours of date at coordinate
    // Call on a background thread (computation takes ~0.5s for 1440 steps)
    func build(at coordinate: CLLocationCoordinate2D, on date: Date, stepSeconds: Int = 60) async {
        isReady = false

        var calendar      : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let startOfDay    : Date     = calendar.startOfDay(for: date)

        let stepCount     : Int                       = 86400 / stepSeconds
        var sunSamples    : [CachedSunMoonPosition] = []
        var moonSamples   : [CachedSunMoonPosition] = []

        sunSamples.reserveCapacity(stepCount)
        moonSamples.reserveCapacity(stepCount)

        for step in 0..<stepCount {
            let sampleTime : Date = startOfDay.addingTimeInterval(Double(step * stepSeconds))

            // Sun position
            let sunPos : SunPosition = SolarCalculator.calcSunPosition(at: coordinate, time: sampleTime)
            sunSamples.append(CachedSunMoonPosition(timestamp: sampleTime, altitude: sunPos.altitude, azimuth: sunPos.azimuth))

            // Moon position
            let (moonAlt, moonAz) = MoonCalculator.calcMoonPosition(at: coordinate, time: sampleTime)
            moonSamples.append(CachedSunMoonPosition(timestamp: sampleTime, altitude: moonAlt, azimuth: moonAz))
        }

        sunPositions      = sunSamples
        moonPositions     = moonSamples
        cachedCoordinate  = coordinate
        cachedDate        = date
        isReady           = true
    }


    // Returns interpolated sun position at the given time
    func sunPosition(at time: Date) -> (altitude: Double, azimuth: Double)? {
        interpolated(from: sunPositions, at: time)
    }

    // Returns interpolated moon position at the given time.
    func moonPosition(at time: Date) -> (altitude: Double, azimuth: Double)? {
        interpolated(from: moonPositions, at: time)
    }

    
    // Returns true if the cache is still valid for the given location and date (location within 200m and same day)
    func isValid(for coordinate: CLLocationCoordinate2D, on date: Date) -> Bool {
        guard let cachedCoord : CLLocationCoordinate2D = cachedCoordinate, let cachedDay : Date = cachedDate
        else { return false }

        let cachedLocation  : CLLocation = CLLocation(latitude: cachedCoord.latitude, longitude: cachedCoord.longitude)
        let currentLocation : CLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceOk      : Bool       = currentLocation.distance(from: cachedLocation) <= 200
        let dateOk          : Bool       = Calendar.current.isDate(date, inSameDayAs: cachedDay)

        return distanceOk && dateOk
    }

    func invalidate() {
        sunPositions     = []
        moonPositions    = []
        cachedCoordinate = nil
        cachedDate       = nil
        isReady          = false
    }

    
    private func interpolated(from positions: [CachedSunMoonPosition], at time: Date) -> (altitude: Double, azimuth: Double)? {
        guard positions.count >= 2 else { return nil }

        // Binary search for the bracketing pair
        var low  : Int = 0
        var high : Int = positions.count - 1

        // Clamp to available range
        if time <= positions.first!.timestamp {
            return (positions.first!.altitude, positions.first!.azimuth)
        }
        if time >= positions.last!.timestamp {
            return (positions.last!.altitude, positions.last!.azimuth)
        }

        while low < high - 1 {
            let mid = (low + high) / 2
            if positions[mid].timestamp <= time {
                low = mid
            } else {
                high = mid
            }
        }

        let before   : CachedSunMoonPosition = positions[low]
        let after    : CachedSunMoonPosition = positions[high]
        let interval : TimeInterval            = after.timestamp.timeIntervalSince(before.timestamp)
        let elapsed  : TimeInterval            = time.timeIntervalSince(before.timestamp)
        let fraction : Double                  = elapsed / interval

        // Linear interpolation for altitude
        let altitude : Double = before.altitude + (after.altitude - before.altitude) * fraction

        // Wraparound-safe interpolation for azimuth
        var delta : Double = after.azimuth - before.azimuth
        if delta >  180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let azimuth           : Double = (before.azimuth + delta * fraction).truncatingRemainder(dividingBy: 360)
        let normalisedAzimuth : Double = azimuth < 0 ? azimuth + 360 : azimuth

        return (altitude, normalisedAzimuth)
    }
}
