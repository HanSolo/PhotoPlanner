//
//  ExposureMath.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//

import Foundation
import SwiftUI


struct ExposureCalculator {

    // Calculates the Exposure Value from aperture, shutter speed and ISO.
    // EV = log2(N² / t) - log2(ISO / 100)
    static func exposureValue(aperture: Double, shutterSpeed: Double, iso: Int) -> Double {
        let evBase : Double = log2((aperture * aperture) / shutterSpeed)
        let isoAdj : Double = log2(Double(iso) / 100.0)
        return evBase - isoAdj
    }

    // Calculates the required shutter speed for setup 2 given the
    // base EV from setup 1, plus new aperture, ISO and ND stops.
    // t = N² / (2^EV * ISO/100) * 2^ndStops
    static func requiredShutterSpeed(baseEV: Double, aperture: Double, iso: Int, ndStops: Int) -> Double {
        let isoFactor   : Double = Double(iso) / 100.0
        let baseShutter : Double = (aperture * aperture) / (pow(2.0, baseEV) * isoFactor)
        return baseShutter * pow(2.0, Double(ndStops))
    }

    
    // Calculates the exact ISO required given base EV,
    // new aperture, shutter speed and ND stops.
    // ISO = 100 * N² / (t * 2^EV) * 2^ndStops
    static func requiredISO(baseEV: Double, aperture: Double, shutterSpeed: Double, ndStops: Int) -> Double {
        let numerator   : Double = aperture * aperture * pow(2.0, Double(ndStops))
        let denominator : Double = shutterSpeed * pow(2.0, baseEV)
        return 100.0 * numerator / denominator
    }

    // Returns the nearest standard ISO to the calculated value.
    static func nearestStandardISO(baseEV: Double, aperture: Double, shutterSpeed: Double, ndStops: Int) -> Int {
        let exact : Double = requiredISO(baseEV: baseEV, aperture: aperture, shutterSpeed: shutterSpeed, ndStops: ndStops)
        return PhotoValues.closestISO(to: exact)
    }

        // ISO range warning, flags if result is outside practical range
    enum ISOWarning {
        case belowBase    // below ISO 64
        case highNoise    // above ISO 6400
        case extremeNoise // above ISO 25600
        case none
    }

    static func isoWarning(for iso: Int) -> ISOWarning {
        switch iso {
            case ..<64        : return .belowBase
            case 6401..<25600 : return .highNoise
            case 25600...     : return .extremeNoise
            default           : return .none
        }
    }
    
    
    // Formats a calculated shutter speed (may exceed standard values).
    // Sub-second : fractional e.g. 1/125s
    // 1...10s    : whole or decimal seconds e.g. 2s, 2.5s
    // 10..30s    : whole seconds e.g. 2s
    // Over 30s   : BULB mode with human-readable duration
    static func formatCalculatedShutter(_ seconds: Double) -> String {

        // Subsecond -> show as fraction
        if seconds < 1.0 {
            let denominator : Double = (1.0 / seconds).rounded()
            return "1/\(Int(denominator))s"
        }

        // 1s to 10s -> show as whole or decimal seconds
        if seconds < 10.0 {
            if seconds == seconds.rounded() {
                return "\(Int(seconds))s"
            } else {
                return String(format: "%.1fs", seconds)
            }
        }
        
        // 10s to 30s -> show as whole seconds
        if seconds <= 30.0 {
            return "\(Int(seconds.rounded()))s"            
        }

        // Over 30s -> BULB mode
        let totalSeconds : Int = Int(seconds.rounded())

        if totalSeconds < 60 {
            // Under a minute -> show seconds only e.g. "BULB 45s"
            return "BULB \(totalSeconds)s"
        }

        let hours         : Int = totalSeconds / 3600
        let minutes       : Int = (totalSeconds % 3600) / 60
        let remainingSecs : Int = totalSeconds % 60

        if hours > 0 {
            // Over an hour e.g. "BULB 1h 2m 30s" or "BULB 1h 2m"
            if remainingSecs == 0 {
                return "BULB \(hours)h \(minutes)m"
            }
            return "BULB \(hours)h \(minutes)m \(remainingSecs)s"
        }

        // 1...59 minutes e.g. "BULB 6m 20s" or "BULB 6m"
        if remainingSecs == 0 {
            return "BULB \(minutes)m"
        }
        return "BULB \(minutes)m \(remainingSecs)s"
    }

    // Returns a color indicating the exposure range
    static func shutterColor(_ seconds: Double) -> Color {
        switch seconds {
            case ..<0.001  : return .red       // extremely short
            case 0.001..<1 : return .green     // standard range
            case 1..<30    : return .orange    // long exposure
            default        : return .purple    // bulb territory
        }
    }
    
    // Returns a color indicating the iso range
    static func isoColor(_ warning: ISOWarning) -> Color {
        switch warning {
            case .none         : return .orange
            case .highNoise    : return .yellow
            case .extremeNoise : return .red
            case .belowBase    : return .red
        }
    }
}
