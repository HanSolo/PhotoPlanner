//
//  MilkywayMapViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 16.06.26.
//


import Foundation
import SwiftUI
import CoreLocation

@Observable
class MilkywayMapViewModel {
    var selectedTime   :  Date                       = Date()
    var isCalculating  :  Bool                       = false
    var positions      :  [MilkywayMapPosition]      = []
    var darknessWindow :  AstronomicalDarknessWindow = AstronomicalDarknessWindow(start: nil, end: nil)
    var timeZone       :  TimeZone                   = .current
    var coordinate     :  CLLocationCoordinate2D?    = nil

    private var cachedCoordinate: CLLocationCoordinate2D?
    private var cachedDate      : Date?

    
    func show(at coordinate: CLLocationCoordinate2D, on date: Date, timeZone: TimeZone) {
        self.timeZone     = timeZone
        self.coordinate   = coordinate
        self.selectedTime = Date()
        buildCache(at: coordinate, on: date, timeZone: timeZone)
    }

    func buildCache(at coordinate: CLLocationCoordinate2D, on date: Date, timeZone: TimeZone) {
        if let cachedCoord = cachedCoordinate, let cachedDay = cachedDate {
            let cached      : CLLocation = CLLocation(latitude: cachedCoord.latitude, longitude: cachedCoord.longitude)
            let current     : CLLocation = CLLocation(latitude: coordinate.latitude,  longitude: coordinate.longitude)
            let sameDay     : Bool       = Calendar.current.isDate(date, inSameDayAs: cachedDay)
            let closeEnough : Bool       = current.distance(from: cached) < 500
            if sameDay && closeEnough && !positions.isEmpty { return }
        }

        isCalculating = true
        positions     = []

        var calendar      : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay    : Date     = calendar.startOfDay(for: date)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var computed: [MilkywayMapPosition] = []
            computed.reserveCapacity(1440)

            for minute in 0..<1440 {
                let sampleTime  : Date   = startOfDay.addingTimeInterval(Double(minute) * 60)
                let sunAltitude : Double = Self.sunAltitude(at: coordinate, time: sampleTime)
                let isDark      : Bool   = sunAltitude < -18

                // Galactic centre position
                let (gcAlt, gcAz) = await GalacticConverter.equatorialToHorizontal(ra: GalacticConverter.galacticCenterRA, dec: GalacticConverter.galacticCenterDec, coordinate: coordinate, time: sampleTime)

                let quality: MilkywayPosition.Quality
                if !isDark || gcAlt <= 0 {
                    quality = .notVisible
                } else {
                    switch gcAlt {
                        case ..<5    : quality = .poor
                        case 5..<15  : quality = .fair
                        case 15..<25 : quality = .good
                        default      : quality = .excellent
                    }
                }
                computed.append(MilkywayMapPosition(time: sampleTime, altitude: gcAlt, azimuth: gcAz, isAstronomicallyDark: isDark,quality: quality))
            }

            let darknessStart : Date? = computed.first { $0.isAstronomicallyDark }?.time
            let darknessEnd   : Date? = computed.last  { $0.isAstronomicallyDark }?.time

            let finalPositions = computed
            
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.positions        = finalPositions
                self.darknessWindow   = AstronomicalDarknessWindow(start: darknessStart, end: darknessEnd)
                self.cachedCoordinate = coordinate
                self.cachedDate       = date
                self.isCalculating    = false
            }
        }
    }

    
    var currentGalacticCenterPosition: (altitude: Double, azimuth: Double, quality: MilkywayPosition.Quality)? {
        guard let coord   : CLLocationCoordinate2D = coordinate else { return nil }        
        let (gcAlt, gcAz) : (Double, Double)       = GalacticConverter.equatorialToHorizontal(ra: GalacticConverter.galacticCenterRA, dec: GalacticConverter.galacticCenterDec, coordinate: coord, time: selectedTime) // precise galactic centre RA and galactic centre Dec
        let isDark        : Bool                   = Self.sunAltitude(at: coord, time: selectedTime) < -18
        let quality       : MilkywayPosition.Quality
        if !isDark || gcAlt <= 0 {
            quality = .notVisible
        } else {
            switch gcAlt {
                case ..<5    : quality = .poor
                case 5..<15  : quality = .fair
                case 15..<25 : quality = .good
                default      : quality = .excellent
            }
        }
        return (gcAlt, gcAz, quality)
    }
    
    var currentPosition: MilkywayMapPosition? {
        guard !positions.isEmpty else { return nil }
        let timestamp : TimeInterval = selectedTime.timeIntervalSince1970
        guard let firstTime : TimeInterval = positions.first?.time.timeIntervalSince1970,
              let lastTime  : TimeInterval = positions.last?.time.timeIntervalSince1970 else { return nil }

        if timestamp <= firstTime { return positions.first }
        if timestamp >= lastTime  { return positions.last  }

        var low = 0, high = positions.count - 1
        while low < high - 1 {
            let mid = (low + high) / 2
            if positions[mid].time.timeIntervalSince1970 <= timestamp { low  = mid }
            else                                                        { high = mid }
        }

        let before   = positions[low]
        let after    = positions[high]
        let fraction = selectedTime.timeIntervalSince(before.time) / after.time.timeIntervalSince(before.time)
        let altitude = before.altitude + (after.altitude - before.altitude) * fraction

        var delta    = after.azimuth - before.azimuth
        if delta >  180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        var azimuth  = (before.azimuth + delta * fraction).truncatingRemainder(dividingBy: 360)
        if azimuth < 0 { azimuth += 360 }

        let isDark   = before.isAstronomicallyDark
        let quality: MilkywayPosition.Quality
        if !isDark || altitude <= 0 {
            quality = .notVisible
        } else {
            switch altitude {
                case ..<5    : quality = .poor
                case 5..<15  : quality = .fair
                case 15..<25 : quality = .good
                default      : quality = .excellent
            }
        }

        return MilkywayMapPosition(time: selectedTime, altitude: altitude, azimuth: azimuth, isAstronomicallyDark: isDark, quality: quality)
    }

    func currentGalacticPlanePoints() -> [(altitude: Double, azimuth: Double)] {
        guard let coord = coordinate else { return [] }
        return GalacticConverter.galacticPlanePoints(at: coord, time: selectedTime, stepDegrees: 2.0)
    }


    var isCurrentlyDark: Bool {
        guard let coord : CLLocationCoordinate2D = coordinate else { return false }
        return Self.sunAltitude(at: coord, time: selectedTime) < -18
    }

    nonisolated static func sunAltitude(at coordinate: CLLocationCoordinate2D, time: Date) -> Double {
        SolarCalculator.calcSunPosition(at: coordinate, time: time).altitude
    }
}
