//
//  HeadingSource.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


enum HeadingSource {
    case compassAutomatic(heading : CLLocationDirection)
    case manualCalibration(ARCalibration)

    var isManuallyCalibrated: Bool {
        if case .manualCalibration = self { return true }
        return false
    }

    var accuracyDescription: String {
        switch self {
            case .compassAutomatic  : return "Compass — tap ⊕ to calibrate"
            case .manualCalibration : return "Calibrated"
        }
    }

    /// Returns the north offset in radians for a given ARKit yaw.
    /// For compass mode: offset = compass heading converted to radians (arKit yaw)
    /// For calibration mode: stored offset from calibration time
    func northOffsetRadians(currentArKitYaw: Float) -> Float {
        switch self {
            case .compassAutomatic(let heading)      : return Float(heading * .pi / 180) - currentArKitYaw
            case .manualCalibration(let calibration) : return calibration.northOffsetRadians
        }
    }
}
