//
//  ARCalibration.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


struct ARCalibration: Codable {
    let arKitYawAtCalibration         : Float   // ARKit's internal yaw angle (radians) at the moment of calibration tap
    let trueNorthHeadingAtCalibration : Double  // True north compass heading (degrees) at the moment of calibration tap
    let calibrationLatitude           : Double  // GPS coordinate where calibration was performed
    let calibrationLongitude          : Double
    let calibrationTimestamp          : Date    // When calibration was performed
    var northOffsetRadians            : Float { // Rotation offset in radians to apply to all celestial direction vectors, positive = rotate clockwise when viewed from above.
        Float(trueNorthHeadingAtCalibration * .pi / 180) - arKitYawAtCalibration
    }

    
    // Returns true if this calibration is still valid for the given location, invalidates if the device has moved more than 50 metres.
    func isValid(at currentLocation: CLLocation) -> Bool {
        let calibrationLocation = CLLocation(latitude:  calibrationLatitude, longitude: calibrationLongitude)
        return currentLocation.distance(from: calibrationLocation) <= 50.0
    }
}
