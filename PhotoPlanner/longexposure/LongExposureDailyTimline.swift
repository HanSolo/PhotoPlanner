//
//  LongExposureDailyTimline.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.05.26.
//

import Foundation


struct LongExposureDailyTimeline {
    let date     : Date
    let slots    : [HourSlot]
    let bestSlot : HourSlot?
    let timeZone : TimeZone

    
    struct HourSlot: Identifiable {
        let id         : UUID = UUID()
        let time       : Date
        let conditions : LongExposureConditions?
        let isSunUp    : Bool
    }
}
