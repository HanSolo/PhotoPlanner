//
//  CachedCelestialPosition.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 24.05.26.
//

import Foundation


struct CachedSunMoonPosition {
    let timestamp : Date
    let altitude  : Double   // degrees
    let azimuth   : Double   // degrees clockwise from north
}
