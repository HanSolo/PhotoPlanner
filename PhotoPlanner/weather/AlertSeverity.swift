//
//  AlertSeverity.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.08.26.
//

import Foundation
import SwiftUI


enum AlertSeverity: String, Comparable {
    case extreme  = "Extreme"
    case severe   = "Severe"
    case moderate = "Moderate"
    case minor    = "Minor"
    case unknown  = "Unknown"
 
    static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        lhs.order < rhs.order
    }
 
    private var order: Int {
        switch self {
            case .extreme  : return 0
            case .severe   : return 1
            case .moderate : return 2
            case .minor    : return 3
            case .unknown  : return 4
        }
    }
 
    var color: Color {
        switch self {
            case .extreme  : return .red
            case .severe   : return .orange
            case .moderate : return .yellow
            case .minor    : return .blue
            case .unknown  : return .gray
        }
    }
 
    var uiColor: UIColor {
        switch self {
            case .extreme  : return .systemRed
            case .severe   : return .systemOrange
            case .moderate : return .systemYellow
            case .minor    : return .systemBlue
            case .unknown  : return .systemGray
        }
    }
}
