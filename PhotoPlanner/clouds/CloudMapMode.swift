//
//  CloudMapMode.swift
//  PhotoPlanner
//

import Foundation
import SwiftUI


enum CloudMapMode: String, CaseIterable {
    case radar     = "Radar"
    case satellite = "Satellite"

    var icon: String {
        switch self {
            case .radar     : return "dot.radiowaves.up.forward"
            case .satellite : return "shower.sidejet"
        }
    }

    var attribution: String {
        switch self {
            case .radar     : return "Precipitation radar (LibreWXR)"
            case .satellite : return "Satellite imagery (LibreWXR)"
        }
    }
}
