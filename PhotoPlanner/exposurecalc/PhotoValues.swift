//
//  PhotoValues.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//

import Foundation
import SwiftUI


struct PhotoValues {

    // Apertures
    static let apertures : [Double] = [
        1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8,
        3.2, 3.5, 4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0,
        10.0, 11.0, 13.0, 14.0, 16.0, 18.0, 20.0, 22.0,
        25.0, 29.0, 32.0
    ]

    // ISOs
    static let isos : [Int] = [
        64, 80, 100, 125, 160, 200, 250, 320, 400, 500,
        640, 800, 1000, 1250, 1600, 2000, 2500, 3200,
        4000, 5000, 6400, 8000, 10000, 12800, 16000,
        20000, 25600, 32000, 40000, 51200, 64000, 80000,
        102400
    ]

    // Full shutter speed range, stored as Double seconds
    static let shutterSpeeds : [Double] = [
        1.0/8000, 1.0/6400, 1.0/5000, 1.0/4000, 1.0/3200, 1.0/2500,
        1.0/2000, 1.0/1600, 1.0/1250, 1.0/1000, 1.0/800,  1.0/640,
        1.0/500,  1.0/400,  1.0/320,  1.0/250,  1.0/200,  1.0/160,
        1.0/125,  1.0/100,  1.0/80,   1.0/60,   1.0/50,   1.0/40,
        1.0/30,   1.0/25,   1.0/20,   1.0/15,   1.0/13,   1.0/10,
        1.0/8,    1.0/6,    1.0/5,    1.0/4,    1.0/3,    1.0/2.5,
        1.0/2,    1.0/1.6,  1.0/1.3,  1.0,      1.3,      1.6,
        2.0,      2.5,      3.0,      4.0,       5.0,      6.0,
        8.0,      10.0,     13.0,     15.0,      20.0,     25.0,
        30.0
    ]

    // ND filter stops
    static let ndStops : [Int] = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 ]
    
    // ND filter names
    static let ndFilterNames : [String] = [ "", "ND 2", "ND 4", "ND 8", "ND 16", "ND 32", "ND 64", "ND 128", "ND 256", "ND 512", "ND 1000", "ND 2000", "ND 4000", "ND 8000", "ND 16000", "ND 32000"]

    
    static func formatAperture(_ value: Double) -> String {
        let formatted : String = value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return "f/\(formatted)"
    }

    static func formatISO(_ value: Int) -> String {
        return "ISO \(value)"
    }

    static func formatShutter(_ seconds: Double) -> String {
        if seconds >= 1.0 {
            if seconds == seconds.rounded() {
                return "\(Int(seconds))s"
            } else {
                return String(format: "%.1fs", seconds)
            }
        } else {
            let denominator : Double = (1.0 / seconds).rounded()
            return "1/\(Int(denominator))"
        }
    }

    static func formatND(_ stops: Int) -> String {
        if stops == 0 { return "No filter" }
        let factor : Int = Int(pow(2.0, Double(stops)))
        return "\(stops) stop\(stops == 1 ? "" : "s") (ND\(factor))"
    }
    
    static func closestAperture(to value: Double) -> Double {
        return apertures.min { abs($0 - value) < abs($1 - value) } ?? 8.0
    }

    static func closestShutter(to value: Double) -> Double {
        return shutterSpeeds.min { abs($0 - value) < abs($1 - value) } ?? 1.0/125
    }
    
    static func closestISO(to value: Double) -> Int {
        isos.min { abs(Double($0) - value) < abs(Double($1) - value) } ?? 64
    }

    static func indexOfAperture(_ value: Double) -> Int {
        return apertures.firstIndex(of: closestAperture(to: value)) ?? 6
    }

    static func indexOfISO(_ value: Int) -> Int {
        return isos.firstIndex(of: value) ?? 0
    }

    static func indexOfShutter(_ value: Double) -> Int {
        return shutterSpeeds.firstIndex(of: closestShutter(to: value)) ?? 18
    }
}
