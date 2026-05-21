//
//  ARCoordinator.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


class ARCoordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate, CLLocationManagerDelegate {
    var onHeadingUpdate   : ((CLLocationDirection) -> Void)?
    var onARYawUpdate     : ((Float) -> Void)?
    var onCalibrationReady: (() -> Void)?

    private      let locationManager         : CLLocationManager   = CLLocationManager()
    private(set) var currentTrueNorthHeading : CLLocationDirection = 0
    private(set) var currentARKitYaw         : Float               = 0

    
    override init() {
        super.init()
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.headingFilter   = 1.0   // update every 1 degree change
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    
    func stopUpdates() {
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        currentTrueNorthHeading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        onHeadingUpdate?(currentTrueNorthHeading)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updates handled by the view model
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Extract yaw from ARKit transform matrix
        let transform : simd_float4x4 = frame.camera.transform
        let yaw       : Float         = atan2(transform.columns.2.x, transform.columns.0.x)
        currentARKitYaw = yaw
        onARYawUpdate?(yaw)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        debugPrint("[ARCelestial] Session failed: \(error.localizedDescription)")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        debugPrint("[ARCelestial] Session interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        debugPrint("[ARCelestial] Session resumed")
    }
}
