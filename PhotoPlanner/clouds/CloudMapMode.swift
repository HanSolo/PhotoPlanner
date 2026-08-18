//
//  CloudMapMode.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 14.08.26.
//

import Foundation


enum CloudMapMode: String, CaseIterable {
    case cloud = "Cloud"
    case radar = "Radar"

    var icon: String {
        switch self {
            case .cloud : return "cloud.fill"
            case .radar : return "dot.radiowaves.up.forward"
        }
    }

    var attribution: String {
        switch self {
            case .cloud : return "Cloud cover — OpenWeatherMap"
            case .radar : return "Precipitation radar — LibreWXR"
        }
    }
}
