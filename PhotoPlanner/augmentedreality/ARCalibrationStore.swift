//
//  ARCalibrationStore.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


class ARCalibrationStore {
    private static let storageKey : String = "ar_calibration"

    static func save(_ calibration: ARCalibration) {
        if let data = try? JSONEncoder().encode(calibration) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func load() -> ARCalibration? {
        guard let data        = UserDefaults.standard.data(forKey: storageKey),
              let calibration = try? JSONDecoder().decode(ARCalibration.self, from: data)
        else { return nil }
        return calibration
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
