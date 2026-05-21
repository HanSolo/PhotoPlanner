//
//  ARViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


@Observable
class ARViewModel {
    var headingSource     : HeadingSource = .compassAutomatic(heading: 0)
    var selectedTime      : Date          = Date()
    var isCalibrating     : Bool          = false
    var calibrationStatus : String        = "Initialising…"
    var currentLocation   : CLLocation?

    private      var coordinator : ARCoordinator?
    private(set) var arSceneView : ARSCNView?

    
    // Scene node names for easy removal and replacement
    private let sunArcNodeName        : String = "sunArc"
    private let moonArcNodeName       : String = "moonArc"
    private let sunIndicatorNodeName  : String = "sunIndicator"
    private let moonIndicatorNodeName : String = "moonIndicator"
    private let cardinalsNodeName     : String = "cardinals"
    private let horizonNodeName       : String = "horizon"
    

    func setup(sceneView: ARSCNView) {
        self.arSceneView = sceneView
        
        let coordinator  : ARCoordinator = ARCoordinator()
        self.coordinator = coordinator

        sceneView.delegate                   = coordinator
        sceneView.session.delegate           = coordinator
        sceneView.scene                      = SCNScene()
        sceneView.autoenablesDefaultLighting = false

        // Start AR session
        let configuration : ARWorldTrackingConfiguration = ARWorldTrackingConfiguration()
        configuration.worldAlignment         = .gravity   // gravity-aligned, not north
        sceneView.session.run(configuration)

        // Wire up callbacks
        coordinator.onHeadingUpdate = { [weak self] heading in
            DispatchQueue.main.async {
                self?.handleHeadingUpdate(heading)
            }
        }

        coordinator.onARYawUpdate = { [weak self] yaw in
            DispatchQueue.main.async {
                self?.handleARYawUpdate(yaw)
            }
        }

        // Load persisted calibration if valid
        loadPersistedCalibrationIfValid()

        // Set selected time to now
        selectedTime = Date()
    }

    func teardown() {
        coordinator?.stopUpdates()
        arSceneView?.session.pause()

        // Save location for next session's calibration validation
        if let location = currentLocation {
            saveLastKnownLocation(location)
        }
    }

    
    private func handleHeadingUpdate(_ heading: CLLocationDirection) {
        // Only update if we're in compass mode
        if case .compassAutomatic = headingSource {
            headingSource      = .compassAutomatic(heading: heading)
            calibrationStatus  = "Compass · \(Int(heading))° — tap ⊕ to calibrate"
            rebuildScene()
        }
    }

    private func handleARYawUpdate(_ yaw: Float) {
        // Update sun/moon indicator positions continuously
        updateIndicatorPositions()
    }

    // Call when the user taps the calibrate button (enters calibration mode)
    func startCalibration() {
        isCalibrating     = true
        calibrationStatus = "Point at true north, then tap Confirm"
    }

    // Call when the user confirms the calibration direction
    func confirmCalibration() {
        guard let coordinator = coordinator else { return }

        let calibration : ARCalibration = ARCalibration(
            arKitYawAtCalibration         : coordinator.currentARKitYaw,
            trueNorthHeadingAtCalibration : coordinator.currentTrueNorthHeading,
            calibrationLatitude           : currentLocation?.coordinate.latitude  ?? 0,
            calibrationLongitude          : currentLocation?.coordinate.longitude ?? 0,
            calibrationTimestamp          : Date()
        )

        headingSource     = .manualCalibration(calibration)
        isCalibrating     = false
        calibrationStatus = "Calibrated ✓"

        ARCalibrationStore.save(calibration)
        rebuildScene()
    }

    func cancelCalibration() {
        isCalibrating     = false
        calibrationStatus = headingSource.accuracyDescription
    }

    func clearCalibration() {
        ARCalibrationStore.clear()
        let currentHeading: CLLocationDirection
        if case .compassAutomatic(let heading) = headingSource {
            currentHeading = heading
        } else {
            currentHeading = coordinator?.currentTrueNorthHeading ?? 0
        }
        headingSource     = .compassAutomatic(heading: currentHeading)
        calibrationStatus = "Calibration cleared — using compass"
        rebuildScene()
    }

    
    private func loadPersistedCalibrationIfValid() {
        guard let saved = ARCalibrationStore.load() else { return }

        // We need the current location to validate (defer until location arrives)
        // For now store the saved calibration and validate when location updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, let location = self.currentLocation else { return }
            if saved.isValid(at: location) {
                self.headingSource     = .manualCalibration(saved)
                self.calibrationStatus = "Calibration restored ✓"
                self.rebuildScene()
            } else {
                ARCalibrationStore.clear()
                self.calibrationStatus = "Location changed, recalibration needed"
            }
        }
    }

    private func saveLastKnownLocation(_ location: CLLocation) {
        UserDefaults.standard.set(location.coordinate.latitude,  forKey: "ar_last_latitude")
        UserDefaults.standard.set(location.coordinate.longitude, forKey: "ar_last_longitude")
    }

    
    func rebuildScene() {
        guard let sceneView = arSceneView, let location  = currentLocation
        else { return }

        let northOffset : Float                  = currentNorthOffset()
        let coordinate  : CLLocationCoordinate2D = location.coordinate

        // Remove existing overlay nodes
        [sunArcNodeName, moonArcNodeName, cardinalsNodeName, horizonNodeName].forEach {
            sceneView.scene.rootNode.childNode(withName: $0, recursively: false)?.removeFromParentNode()
        }

        // Sun arc
        let sunArcNode    : SCNNode = ARSceneBuilder.buildSunArcNode(coordinate: coordinate, date: selectedTime, northOffsetRadians: northOffset)
        sunArcNode.name = sunArcNodeName
        sceneView.scene.rootNode.addChildNode(sunArcNode)

        // Moon arc
        let moonArcNode   : SCNNode = ARSceneBuilder.buildMoonArcNode(coordinate: coordinate, date: selectedTime, northOffsetRadians: northOffset)
        moonArcNode.name = moonArcNodeName
        sceneView.scene.rootNode.addChildNode(moonArcNode)

        // Cardinals
        let cardinalsNode : SCNNode = ARSceneBuilder.buildCardinalMarkersNode(northOffsetRadians: northOffset)
        cardinalsNode.name = cardinalsNodeName
        sceneView.scene.rootNode.addChildNode(cardinalsNode)

        // Horizon ring
        let horizonNode   : SCNNode = ARSceneBuilder.buildHorizonRingNode(northOffsetRadians: northOffset)
        horizonNode.name = horizonNodeName
        sceneView.scene.rootNode.addChildNode(horizonNode)

        // Update indicators
        updateIndicatorPositions()
    }

    func updateIndicatorPositions() {
        guard let sceneView = arSceneView, let location  = currentLocation
        else { return }

        let northOffset : Float                  = currentNorthOffset()
        let coordinate  : CLLocationCoordinate2D = location.coordinate

        // Sun indicator
        let sunPos = Helper.calcSunPos(at: coordinate, time: selectedTime)

        sceneView.scene.rootNode.childNode(withName: sunIndicatorNodeName, recursively: false)?.removeFromParentNode()

        if sunPos.altitude > -6 {
            var sunDirection : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: sunPos.azimuth, altitudeDegrees: sunPos.altitude)
            sunDirection = CoordinateConverter.applyNorthOffset(to: sunDirection, offsetRadians: northOffset)
            
            let sunIndicator : SCNNode    = ARSceneBuilder.buildSunIndicatorNode()
            sunIndicator.position = CoordinateConverter.spherePosition(direction: sunDirection, radius: ARSceneBuilder.celestialSphereRadius)
            sunIndicator.name     = sunIndicatorNodeName
            sceneView.scene.rootNode.addChildNode(sunIndicator)
        }

        // Moon indicator
        sceneView.scene.rootNode.childNode(withName: moonIndicatorNodeName, recursively: false)?.removeFromParentNode()

        let (moonAltitude, moonAzimuth) = MoonCalculator.calcMoonPosition(at: coordinate, time: selectedTime)

        if moonAltitude > 0 {
            let moonPhase     : MoonPhase  = MoonCalculator.calcMoonPhase(at: coordinate, time: selectedTime, timeZone: TimeZone.current)
            var moonDirection : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: moonAzimuth, altitudeDegrees: moonAltitude)
            moonDirection = CoordinateConverter.applyNorthOffset(to: moonDirection, offsetRadians: northOffset)
            
            let moonIndicator : SCNNode    = ARSceneBuilder.buildMoonIndicatorNode(illumination: moonPhase.illumination)
            moonIndicator.position = CoordinateConverter.spherePosition(direction: moonDirection, radius: ARSceneBuilder.celestialSphereRadius)
            moonIndicator.name     = moonIndicatorNodeName
            sceneView.scene.rootNode.addChildNode(moonIndicator)
        }
    }

    private func currentNorthOffset() -> Float {
        guard let coordinator = coordinator else { return 0 }
        return headingSource.northOffsetRadians( currentArKitYaw: coordinator.currentARKitYaw)
    }

    func updateLocation(_ location: CLLocation) {
        currentLocation = location
    }

    func updateSelectedTime(_ time: Date) {
        selectedTime = time
        updateIndicatorPositions()
    }

    func updateSelectedTimeAndRebuild(_ time: Date) {
        selectedTime = time
        rebuildScene()
    }
}
