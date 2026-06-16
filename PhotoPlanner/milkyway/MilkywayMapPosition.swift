//
//  MilkywayMapPosition.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 16.06.26.
//


import Foundation
import SwiftUI
import CoreLocation

struct MilkywayMapPosition {
    let time                 : Date
    let altitude             : Double   // degrees above horizon
    let azimuth              : Double   // degrees clockwise from north
    let isAstronomicallyDark : Bool     // sun below -18°
    let quality              : MilkywayPosition.Quality
}