//
//  AstronomicalDarknessWindow.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 16.06.26.
//


import Foundation
import SwiftUI
import CoreLocation

struct AstronomicalDarknessWindow {
    let start       : Date?   // nil = no darkness (e.g. summer in high latitudes)
    let end         : Date?
    var hasDarkness : Bool { start != nil && end != nil }

    
    func startFraction(relativeTo startOfDay: Date) -> Double? {
        start.map { $0.timeIntervalSince(startOfDay) / 86400 }
    }

    
    func endFraction(relativeTo startOfDay: Date) -> Double? {
        end.map { $0.timeIntervalSince(startOfDay) / 86400 }
    }
}