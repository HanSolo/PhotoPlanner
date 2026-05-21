//
//  SunPosition.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import Foundation
import CoreLocation

struct SunPosition {
    let time     : Date
    let altitude : Double   // degrees above flat horizon
    let azimuth  : Double   // degrees clockwise from north
}