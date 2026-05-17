//
//  MoonPhase.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.05.26.
//

import Foundation
import SwiftUI


struct MoonPhase {
    let date         : Date
    let illumination : Double    // 0.0 to 1.0
    let phaseAngle   : Double    // degrees 0–360
    let phaseName    : PhaseName
    let isWaxing     : Bool
    let riseTime     : Date?
    let setTime      : Date?
    let altitude     : Double    // at requested time
    let azimuth      : Double    // at requested time
    let timeZone     : TimeZone

    
    enum PhaseName: String {
        case newMoon        = "New Moon"
        case waxingCrescent = "Waxing Crescent"
        case firstQuarter   = "First Quarter"
        case waxingGibbous  = "Waxing Gibbous"
        case fullMoon       = "Full Moon"
        case waningGibbous  = "Waning Gibbous"
        case lastQuarter    = "Last Quarter"
        case waningCrescent = "Waning Crescent"

        var symbol: String {
            switch self {
                case .newMoon        : return "🌑"
                case .waxingCrescent : return "🌒"
                case .firstQuarter   : return "🌓"
                case .waxingGibbous  : return "🌔"
                case .fullMoon       : return "🌕"
                case .waningGibbous  : return "🌖"
                case .lastQuarter    : return "🌗"
                case .waningCrescent : return "🌘"
            }
        }

        /// Impact on astrophotography: higher = more interference
        var lightPollutionFactor: Double {
            switch self {
                case .newMoon        : return 0.0
                case .waxingCrescent : return 0.1
                case .firstQuarter   : return 0.3
                case .waxingGibbous  : return 0.6
                case .fullMoon       : return 1.0
                case .waningGibbous  : return 0.6
                case .lastQuarter    : return 0.3
                case .waningCrescent : return 0.1
            }
        }

        var color: Color {
            switch self {
                case .newMoon                         : return .gray
                case .waxingCrescent, .waningCrescent : return .yellow.opacity(0.6)
                case .firstQuarter,   .lastQuarter    : return .yellow.opacity(0.8)
                case .waxingGibbous,  .waningGibbous  : return .orange
                case .fullMoon                        : return .white
            }
        }
    }
}
