//
//  MilkywayPosition.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 12.05.26.
//

import Foundation
import SwiftUI
import CoreLocation


struct MilkywayPosition {
    let time:          Date
    let altitude:      Double    // degrees above horizon
    let azimuth:       Double    // degrees clockwise from north
    let isVisible:     Bool      // above horizon + astronomical dark
    let coreAltitude:  Double    // galactic centre altitude
    let quality:       Quality

    enum Quality: String {
        case notVisible = "Not Visible"
        case poor       = "Poor"
        case fair       = "Fair"
        case good       = "Good"
        case excellent  = "Excellent"

        var color: Color {
            switch self {
                case .notVisible : return .gray
                case .poor       : return .blue.opacity(0.6)
                case .fair       : return .indigo
                case .good       : return .purple
                case .excellent  : return .white
            }
        }
    }
}
