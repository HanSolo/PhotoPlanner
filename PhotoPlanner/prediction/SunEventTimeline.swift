//
//  SunEventTimeline.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation


struct SunEventTimeline {
    let event    : SolarEvent
    let slots    : [TimeSlot]
    let peakSlot : TimeSlot?

    
    struct TimeSlot: Identifiable {
        let id           : UUID = UUID()
        let time         : Date
        let score        : SunriseSunsetScore
        let minuteOffset : Int   // relative to event time
    }
}
