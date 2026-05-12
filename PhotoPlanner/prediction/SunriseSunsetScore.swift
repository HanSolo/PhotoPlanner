//
//  SunriseSunsetScore.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation
import SwiftUI


struct SunriseSunsetScore {
    let overall         : Grade
    let cloudScore      : Double
    let humidityScore   : Double
    let visibilityScore : Double
    let reasoning       : [String]

    
    enum Grade: String {
        case poor  = "Poor"
        case fair  = "Fair"
        case good  = "Good"
        case great = "Great"
        case grand = "Grand"

        var color: Color {
            switch self {
                case .poor  : return .gray
                case .fair  : return .yellow
                case .good  : return .orange
                case .great : return .pink
                case .grand : return .red
            }
        }

        var systemImage: String {
            switch self {
                case .poor  : return "cloud.fill"
                case .fair  : return "cloud.sun.fill"
                case .good  : return "sun.horizon.fill"
                case .great : return "sun.horizon.fill"
                case .grand : return "sparkles"
            }
        }
    }
}
