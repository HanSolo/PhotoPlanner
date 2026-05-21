//
//  TerrainAdjustedEphemeris.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import Foundation
import CoreLocation

struct TerrainAdjustedEphemeris {
    let flatHorizonSunrise : Date?
    let terrainSunrise     : Date?
    let terrainDelay       : TimeInterval?

    let flatHorizonSunset  : Date?
    let terrainSunset      : Date?
    let terrainAdvance     : TimeInterval?

    let horizonAngle       : Double
}