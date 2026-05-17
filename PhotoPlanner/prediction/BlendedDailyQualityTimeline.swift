//
//  BlendedDailyQualityTimeline.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 17.05.26.
//

import Foundation
import CoreLocation


struct BlendedDailyQualityTimeline {
    let date                    : Date
    let slots                   : [BlendedHourSlot]
    let bestSunrise             : BlendedHourSlot?
    let bestSunset              : BlendedHourSlot?
    let timeZone                : TimeZone
    let sunriseRemoteCoordinate : CLLocationCoordinate2D?
    let sunsetRemoteCoordinate  : CLLocationCoordinate2D?

    
    struct BlendedHourSlot: Identifiable {
        let id                  : UUID  = UUID()
        let time                : Date
        let blendedScore        : SunriseSunsetScore?
        let cameraLocationScore : SunriseSunsetScore?
        let remoteLocationScore : SunriseSunsetScore?
        let sunAltitude         : Double
        let sunAzimuth          : Double
        let isSunUp             : Bool
        let isGoldenHour        : Bool
    }
}
