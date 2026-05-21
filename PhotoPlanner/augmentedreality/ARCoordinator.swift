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
    var onHeadingUpdate   : ((CLLocationDirection, String) -> Void)?
    var onARYawUpdate     : ((Float) -> Void)?
    var onCalibrationReady: (() -> Void)?

    private      let locationManager         : CLLocationManager     = CLLocationManager()
    private(set) var currentTrueNorthHeading : CLLocationDirection   = 0
    private(set) var currentARKitYaw         : Float                 = 0
    
    private      var headingBuffer           : [CLLocationDirection] = []
    private      let headingBufferSize       : Int                   = 5   // average over last 5 readings (~1 - 2 seconds), maybe 8-10 readings will even be better


    
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

        let rawHeading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading

        // Add to buffer, keep only last N readings
        headingBuffer.append(rawHeading)
        if headingBuffer.count > headingBufferSize {
            headingBuffer.removeFirst()
        }

        // Average, but handle the 0°/360° wraparound correctly
        // A naive average of [359°, 1°] would give 180° which is wrong
        let smoothedHeading : CLLocationDirection = averageHeading(headingBuffer)
        currentTrueNorthHeading = smoothedHeading

        let accuracy            : CLLocationDirection = newHeading.headingAccuracy
        let accuracyDescription : String
        switch accuracy {
            case ..<5    : accuracyDescription = "Compass ±\(Int(accuracy))° — excellent"
            case 5..<15  : accuracyDescription = "Compass ±\(Int(accuracy))° — good"
            case 15..<30 : accuracyDescription = "Compass ±\(Int(accuracy))° — tap ⊕ to calibrate"
            default      : accuracyDescription = "Compass unreliable — tap ⊕ to calibrate"
        }

        onHeadingUpdate?(smoothedHeading, accuracyDescription)
    }
    
    // Averages headings correctly across the 0°/360° boundary by converting to unit vectors, averaging, then converting back.
    private func averageHeading(_ headings: [CLLocationDirection]) -> CLLocationDirection {
        guard !headings.isEmpty else { return 0 }

        // Convert each heading to a unit vector and sum
        var sumX : Double = 0.0
        var sumY : Double = 0.0
        for heading in headings {
            let radians = heading * .pi / 180
            sumX += cos(radians)
            sumY += sin(radians)
        }

        // Convert summed vector back to angle
        let averageRadians : Double = atan2(sumY / Double(headings.count), sumX / Double(headings.count))
        var averageDegrees : Double = averageRadians * 180 / .pi
        if averageDegrees < 0 { averageDegrees += 360 }
        return averageDegrees
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
