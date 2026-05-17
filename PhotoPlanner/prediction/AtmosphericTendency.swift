//
//  AtmosphericTendency.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 17.05.26.
//

import Foundation


struct AtmosphericTendency {
    let isPressureRising      : Bool
    let isPostFrontal         : Bool    // rain in last 12h followed by clearing
    let isConditionsImproving : Bool    // cloud cover decreasing trend
    let tendencyBonus         : Double  // 0.0–0.2 bonus to composite score
}
