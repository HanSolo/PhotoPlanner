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
import MapKit
internal import Combine


@Observable
class ARViewModel {
    var headingSource     : HeadingSource = .compassAutomatic(heading: 0)
    var selectedTime      : Date          = Date()
    var isCalibrating     : Bool          = false
    var calibrationStatus : String        = "Initialising…"
    var currentLocation   : CLLocation?

    private      var coordinator    : ARCoordinator?
    private(set) var arSceneView    : ARSCNView?
    private      var cachedTimeZone : TimeZone?

    
    // Scene node names for easy removal and replacement
    private let sunArcNodeName         : String = "sunArc"
    private let moonArcNodeName        : String = "moonArc"
    private let sunIndicatorNodeName   : String = "sunIndicator"
    private let moonIndicatorNodeName  : String = "moonIndicator"
    private let cardinalsNodeName      : String = "cardinals"
    private let horizonNodeName        : String = "horizon"
    private let sunHourLabelsNodeName  : String = "sunHours"
    private let moonHourLabelsNodeName : String = "moonHours"
    

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
        coordinator.onHeadingUpdate = { [weak self] heading, accuracyDescription in
            DispatchQueue.main.async {
                self?.handleHeadingUpdate(heading, accuracyDescription: accuracyDescription)
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

    private func handleHeadingUpdate(_ heading: CLLocationDirection, accuracyDescription: String) {
        if case .compassAutomatic = headingSource {
            headingSource      = .compassAutomatic(heading: heading)
            calibrationStatus  = accuracyDescription
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
        guard let location = currentLocation else { return }

        let northOffset = currentNorthOffset()
        let coordinate  = location.coordinate
        let date        = selectedTime
                
        Task {
            let timeZone: TimeZone
            if let cached = self.cachedTimeZone {
                timeZone = cached
            } else {
                timeZone = (try? await fetchTimeZone(for: location)) ?? .current
                await MainActor.run { self.cachedTimeZone = timeZone }
            }
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Fetch timezone for the camera location
            let timeZone = (try? await self.fetchTimeZone(for: location)) ?? .current

            // Step 1 — pure math, background thread safe
            let sunArcPoints    : [ArcPoint]       = ARSceneBuilder.computeSunArcPoints(coordinate: coordinate, date: date, northOffsetRadians: northOffset)
            let moonArcPoints   : [ArcPoint]       = ARSceneBuilder.computeMoonArcPoints(coordinate: coordinate, date: date, northOffsetRadians: northOffset)
            let sunLabelPoints  : [HourLabelPoint] = ARSceneBuilder.computeSunHourLabelPoints(coordinate: coordinate, date: date,northOffsetRadians: northOffset, timeZone: timeZone)
            let moonLabelPoints : [HourLabelPoint] = ARSceneBuilder.computeMoonHourLabelPoints(coordinate: coordinate, date: date, northOffsetRadians: northOffset, timeZone: timeZone)
            let cardinalPoints  : [(position: SCNVector3, label: String)] = ARSceneBuilder.computeCardinalPoints(northOffsetRadians: northOffset)
            let horizonPoints   : [ArcPoint] = ARSceneBuilder.computeHorizonRingPoints(northOffsetRadians: northOffset)

            // Step 2 — SceneKit node creation, main thread
            await MainActor.run { [weak self] in
                guard let self, let sceneView = self.arSceneView else { return }

                let sunArcNode     : SCNNode = ARSceneBuilder.buildArcNode(from: sunArcPoints,  lineRadius: 0.075)
                sunArcNode.name = self.sunArcNodeName

                let moonArcNode    : SCNNode = ARSceneBuilder.buildArcNode(from: moonArcPoints, lineRadius: 0.05)
                moonArcNode.name = self.moonArcNodeName

                let sunLabelsNode  : SCNNode = ARSceneBuilder.buildHourLabelsNode(from: sunLabelPoints)
                sunLabelsNode.name = self.sunHourLabelsNodeName

                let moonLabelsNode : SCNNode = ARSceneBuilder.buildHourLabelsNode(from: moonLabelPoints)
                moonLabelsNode.name = self.moonHourLabelsNodeName

                let cardinalsNode  : SCNNode = ARSceneBuilder.buildCardinalMarkersNode(from: cardinalPoints)
                cardinalsNode.name = self.cardinalsNodeName

                let horizonNode    : SCNNode = ARSceneBuilder.buildHorizonRingNode(from: horizonPoints)
                horizonNode.name = self.horizonNodeName

                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0
                SCNTransaction.disableActions    = true

                [self.sunArcNodeName, self.moonArcNodeName, self.cardinalsNodeName, self.horizonNodeName, self.sunHourLabelsNodeName, self.moonHourLabelsNodeName].forEach {
                    sceneView.scene.rootNode.childNode(withName: $0, recursively: false)?
                        .removeFromParentNode()
                }

                sceneView.scene.rootNode.addChildNode(sunArcNode)
                sceneView.scene.rootNode.addChildNode(moonArcNode)
                sceneView.scene.rootNode.addChildNode(sunLabelsNode)
                sceneView.scene.rootNode.addChildNode(moonLabelsNode)
                sceneView.scene.rootNode.addChildNode(cardinalsNode)
                sceneView.scene.rootNode.addChildNode(horizonNode)

                SCNTransaction.commit()

                self.updateIndicatorPositions()
            }
        }
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
    
    func updateLocation(_ location: CLLocation) {
        // Invalidate timezone cache if moved more than 50km
        if let current = currentLocation,
           location.distance(from: current) > 50000 {
            cachedTimeZone = nil
        }
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
    
    private func currentNorthOffset() -> Float {
        guard let coordinator = coordinator else { return 0 }
        return headingSource.northOffsetRadians( currentArKitYaw: coordinator.currentARKitYaw)
    }
    
    private func fetchTimeZone(for location: CLLocation) async throws -> TimeZone? {
        let request = MKReverseGeocodingRequest(location: CLLocation(latitude:  location.coordinate.latitude, longitude: location.coordinate.longitude))
        return try await request?.mapItems.first?.timeZone
    }
}
