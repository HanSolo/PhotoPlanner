//
//  DailyQualityTimeline.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation


struct DailyQualityTimeline {
    let date        : Date
    let slots       : [HourSlot]
    let bestSunrise : HourSlot?   // peak quality hour in the morning
    let bestSunset  : HourSlot?   // peak quality hour in the evening
    let timeZone    : TimeZone

    
    struct HourSlot: Identifiable {
        let id          : UUID = UUID()
        let time        : Date
        let score       : SunriseSunsetScore?  // nil during night
        let sunAltitude : Double               // degrees
        let sunAzimuth  : Double               // degrees
        let isSunUp     : Bool                 // includes civil twilight
    }
}
