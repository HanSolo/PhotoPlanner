//
//  FieldOfViewMath.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.05.26.
//

import Foundation
import SwiftUI


struct FieldOfViewCalculator {

    // Horizontal and vertical field of view angles in radians
    static func fovAngles(focalLength: Double, sensorWidth: Double, sensorHeight: Double) -> (horizontal: Double, vertical: Double) {
        let horizontal : Double = 2 * atan(sensorWidth  / (2 * focalLength))
        let vertical   : Double = 2 * atan(sensorHeight / (2 * focalLength))
        return (horizontal, vertical)
    }

    // Minimum distance to fit a given field dimension into the frame (fieldSize: meter, fovAngle: radians, result: meter)
    static func minimumDistance(fieldSize: Double, fovAngle: Double) -> Double {
        return fieldSize / (2 * tan(fovAngle / 2))
    }

    // Field size at a given distance (distance: meter, fovAngle: radians, result: meter)
    static func fieldSize(distance: Double, fovAngle: Double) -> Double {
        2 * distance * tan(fovAngle / 2)
    }

    // Formats a distance in meter to a human readable string
    static func formatDistance(_ meter: Double) -> String {
        switch meter {
            case ..<1       : return String(format: "%.0f cm", meter * 100)
            case 1..<10     : return String(format: "%.2f m", meter)
            case 10..<100   : return String(format: "%.1f m", meter)
            case 100..<1000 : return String(format: "%.0f m", meter)
            default         : return String(format: "%.2f km", meter / 1000)
        }
    }

    // Formats a field size in meter
    static func formatFieldSize(_ meter: Double) -> String {
        switch meter {
            case ..<1     : return String(format: "%.1f cm", meter * 100)
            case 1..<1000 : return String(format: "%.1f m", meter)
            default       : return String(format: "%.0f m", meter)
        }
    }

    // Converts a linear slider value (0...1) to meter using a logarithmic scale across 0.1m to 1000m
    static func sliderToMetres(_ value: Double) -> Double {
        let minLog : Double = log10(0.1)    // -1
        let maxLog : Double = log10(1000)   //  3
        return pow(10, minLog + value * (maxLog - minLog))
    }

    // Converts metres to a linear slider value (0...1)
    static func metresToSlider(_ metres: Double) -> Double {
        let minLog  : Double = log10(0.1)
        let maxLog  : Double = log10(1000)
        let clamped : Double = max(0.1, min(1000, metres))
        return (log10(clamped) - minLog) / (maxLog - minLog)
    }
}
