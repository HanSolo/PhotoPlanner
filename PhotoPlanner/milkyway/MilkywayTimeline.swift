//
//  MilkywayTimeline.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 12.05.26.
//

import Foundation


struct MilkywayTimeline {
    let date        : Date
    let slots       : [MilkywayPosition]
    let peakSlot    : MilkywayPosition?   // highest altitude during darkness
    let windowStart : Date?               // start of viable shooting window
    let windowEnd   : Date?               // end of viable shooting window
    let timeZone    : TimeZone
}
