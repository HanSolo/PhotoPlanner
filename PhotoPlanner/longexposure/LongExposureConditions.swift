//
//  LongExposureConditions.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.05.26.
//

import Foundation
import SwiftUI


struct LongExposureConditions {
    let overall             : Grade
    let cloudScore          : Double
    let windScore           : Double
    let sunAngleScore       : Double
    let windCloudAlignment  : WindCloudAlignment
    let recommendedExposure : RecommendedExposure
    let reasoning           : [String]

    
    enum Grade: String {
        case poor  = "Poor"
        case fair  = "Fair"
        case good  = "Good"
        case great = "Great"
        case grand = "Grand"

        var color: Color {
            switch self {
                case .poor  : return .gray
                case .fair  : return .yellow.opacity(0.8)
                case .good  : return .green
                case .great : return .mint
                case .grand : return .white
            }
        }

        var systemImage: String {
            switch self {
                case .poor  : return "cloud.slash"
                case .fair  : return "cloud"
                case .good  : return "cloud.fill"
                case .great : return "cloud.sun.fill"
                case .grand : return "sparkles"
            }
        }
    }

    /// Describes the relationship between wind direction and camera heading.
    enum WindCloudAlignment: String {
        case parallel      = "Parallel"       // dynamic explosion-like cloud effect
        case diagonal      = "Diagonal"       // twisted diagonal cloud streaks
        case perpendicular = "Perpendicular"  // soft cotton-ball clouds
        case unknown       = "Unknown"

        nonisolated var effectDescription: String {
            switch self {
                case .parallel      : return "Expect dynamic, explosion-like cloud streaks"
                case .diagonal      : return "Expect twisted diagonal cloud streaks"
                case .perpendicular : return "Expect soft, cotton-ball clouds"
                case .unknown       : return "Wind direction unavailable"
            }
        }
    }

    /// Recommended exposure time based on wind speed (Beaufort scale).
    /// 5-6 Bft = 15 sec, 3-4 Bft = 30 sec, <=>2 Bft = 1-2 min.
    enum RecommendedExposure: String {
        case veryShort = "~15 sec"    // 5–6 Beaufort
        case short     = "~30 sec"    // 3–4 Beaufort
        case medium    = "1–2 min"    // ~2 Beaufort
        case long      = "2–4 min"    // < 2 Beaufort — marginal
        case tooCalm   = "> 4 min"    // barely any movement
    }
}
