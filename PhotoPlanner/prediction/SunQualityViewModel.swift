//
//  SunQualityViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation
import CoreLocation
import SwiftUI


@Observable
class SunQualityViewModel {
    var dailyTimeline : DailyQualityTimeline?
    var error         : Error?
    var isVisible     : Bool  = false

    private let predictor = SunriseSunsetPredictor()
    
    
    func fetch(at location: CLLocationCoordinate2D, on date: Date, shootAzimuth: Double, configuration: RemoteWeatherConfiguration = SunriseSunsetPredictor.inland) async {
        dailyTimeline = nil
        error         = nil

        do {
            let blendedTimeline = try await predictor.getBlendedDailyTimeline(at: location, on: date, shootAzimuth: shootAzimuth, configuration: configuration)

            // Convert to the existing DailyQualityTimeline so the
            // existing DailyQualityView works without any changes
            dailyTimeline = DailyQualityTimeline(date: blendedTimeline.date,
                slots: blendedTimeline.slots.map { blendedSlot in
                    DailyQualityTimeline.HourSlot(
                        time         : blendedSlot.time,
                        score        : blendedSlot.blendedScore,
                        sunAltitude  : blendedSlot.sunAltitude,
                        sunAzimuth   : blendedSlot.sunAzimuth,
                        isSunUp      : blendedSlot.isSunUp,
                        isGoldenHour : blendedSlot.isGoldenHour
                    )
                },
                bestSunrise: blendedTimeline.bestSunrise.map { blendedSlot in
                    DailyQualityTimeline.HourSlot(
                        time         : blendedSlot.time,
                        score        : blendedSlot.blendedScore,
                        sunAltitude  : blendedSlot.sunAltitude,
                        sunAzimuth   : blendedSlot.sunAzimuth,
                        isSunUp      : blendedSlot.isSunUp,
                        isGoldenHour : blendedSlot.isGoldenHour
                    )
                },
                bestSunset: blendedTimeline.bestSunset.map { blendedSlot in
                    DailyQualityTimeline.HourSlot(
                        time         : blendedSlot.time,
                        score        : blendedSlot.blendedScore,
                        sunAltitude  : blendedSlot.sunAltitude,
                        sunAzimuth   : blendedSlot.sunAzimuth,
                        isSunUp      : blendedSlot.isSunUp,
                        isGoldenHour : blendedSlot.isGoldenHour
                    )
                },
                timeZone: blendedTimeline.timeZone
            )
        } catch {
            self.error = error
        }
    }
    
    func dismiss() {
        dailyTimeline = nil
        isVisible     = false
    }
}
