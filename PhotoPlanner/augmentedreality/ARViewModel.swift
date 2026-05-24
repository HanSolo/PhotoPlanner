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
    
    private      var coordinator             : ARCoordinator?
    private(set) var arSceneView             : ARSCNView?
    private      var cachedTimeZone          : TimeZone?
        
    private      var sceneNorthOffset        : Float = 0 // The north offset used when the current scene was last built
    private      var hasReceivedFirstHeading : Bool  = false
    private      var isRebuildingScene       : Bool  = false
    private      var previousSceneHeading    : CLLocationDirection?
    private      let positionCache           : SunMoonPositionCache = SunMoonPositionCache()
    private      var isCacheBuilding         : Bool     = false

    
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
            headingSource     = .compassAutomatic(heading: heading)
            calibrationStatus = accuracyDescription

            if !hasReceivedFirstHeading {
                hasReceivedFirstHeading = true
                previousSceneHeading    = heading
                rebuildScene()
            } else {
                // Subsequent heading updates (only rebuild if heading)
                // has changed significantly (more than 5 degrees)
                // to avoid constant rebuilds from compass noise
                if let previousOffset = previousSceneHeading {
                    let delta        : Double = abs(heading - previousOffset)
                    let wrappedDelta : Double = min(delta, 360 - delta)
                    if wrappedDelta > 5 {
                        previousSceneHeading = heading
                        rebuildScene()
                    }
                } else {
                    previousSceneHeading = heading
                }
            }
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

    
    func buildPositionCache() {
        guard let location : CLLocation = currentLocation else { return }
        guard !isCacheBuilding else { return }

        isCacheBuilding = true

        // Capture values on background thread
        let coordinate : CLLocationCoordinate2D = location.coordinate
        let date       : Date                   = selectedTime

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Build entirely on background thread, no MainActor involvement
            await self.positionCache.build(at: coordinate, on: date)

            // Only touch UI on main thread once complete
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isCacheBuilding = false
                self.rebuildScene()
            }
        }
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
        guard let location : CLLocation = self.currentLocation else { return }
        guard !self.isRebuildingScene else { return } //print("[ARCelestial] rebuildScene skipped — already rebuilding")

        self.isRebuildingScene = true
        
        let northOffset    : Float = currentNorthOffset()
        sceneNorthOffset = northOffset
    
        let coordinate     : CLLocationCoordinate2D = location.coordinate
        let date           : Date                   = selectedTime
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let timeZone: TimeZone
            if let cached = await self.cachedTimeZone {
                timeZone = cached
            } else {
                timeZone = (try? await fetchTimeZone(for: location)) ?? .current
                await MainActor.run { self.cachedTimeZone = timeZone }
            }
            
            // Step 1 — pure math, background thread safe
            let sunArcPoints    : [ArcPoint]       = ARSceneBuilder.computeSunArcPoints(coordinate: coordinate, date: date, northOffsetRadians: northOffset, timeZone: timeZone)
            let moonArcPoints   : [ArcPoint]       = ARSceneBuilder.computeMoonArcPoints(coordinate: coordinate, date: date, northOffsetRadians: northOffset, timeZone: timeZone)
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
                
                self.isRebuildingScene = false
            }
        }
    }

    func updateIndicatorPositions() {
        guard let sceneView : ARSCNView = arSceneView, let location : CLLocation = currentLocation
        else { return }

        let northOffset : Float                  = sceneNorthOffset
        let coordinate  : CLLocationCoordinate2D = location.coordinate
        let time        : Date                   = selectedTime

        Task { @MainActor in
            let sunPos  : (altitude: Double, azimuth: Double)?
            let moonPos : (altitude: Double, azimuth: Double)?

            if await positionCache.isReady {
                sunPos  = await positionCache.sunPosition(at: time)
                moonPos = await positionCache.moonPosition(at: time)
            } else {
                let liveSun : SunPosition = SolarCalculator.calcSunPosition(at: coordinate, time: time)
                sunPos  = (liveSun.altitude, liveSun.azimuth)
                moonPos = MoonCalculator.calcMoonPosition(at: coordinate, time: time)
            }

            // Sun indicator
            sceneView.scene.rootNode.childNode(withName: sunIndicatorNodeName, recursively: false)?.removeFromParentNode()

            if let sun = sunPos, sun.altitude > -6 {
                var sunDirection : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: sun.azimuth, altitudeDegrees: sun.altitude)
                sunDirection = CoordinateConverter.applyNorthOffset(to: sunDirection, offsetRadians: northOffset)
                
                let sunIndicator : SCNNode = ARSceneBuilder.buildSunIndicatorNode()
                sunIndicator.position = CoordinateConverter.spherePosition(direction: sunDirection, radius: ARSceneBuilder.celestialSphereRadius)
                sunIndicator.name     = sunIndicatorNodeName
                sceneView.scene.rootNode.addChildNode(sunIndicator)
            }

            // Moon indicator
            sceneView.scene.rootNode.childNode(withName: moonIndicatorNodeName, recursively: false)?.removeFromParentNode()

            if let moon = moonPos, moon.altitude > 0 {
                let moonPhase     : MoonPhase  = MoonCalculator.calcMoonPhase(at: coordinate, time: time, timeZone: TimeZone.current)
                var moonDirection : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: moon.azimuth, altitudeDegrees: moon.altitude)
                moonDirection = CoordinateConverter.applyNorthOffset(to: moonDirection, offsetRadians: northOffset)
                
                let moonIndicator : SCNNode = ARSceneBuilder.buildMoonIndicatorNode(illumination: moonPhase.illumination)
                moonIndicator.position = CoordinateConverter.spherePosition(direction: moonDirection, radius: ARSceneBuilder.celestialSphereRadius)
                moonIndicator.name     = moonIndicatorNodeName
                sceneView.scene.rootNode.addChildNode(moonIndicator)
            }
        }
    }
    
    func updateLocation(_ location: CLLocation) {
        // Invalidate timezone cache if moved more than 50km
        if let current = currentLocation,
           location.distance(from: current) > 50000 {
            cachedTimeZone = nil
        }
        currentLocation = location

        Task {
            let needsRebuild = await !positionCache.isValid(for: location.coordinate, on: selectedTime)
            if needsRebuild {
                await MainActor.run { self.buildPositionCache() }
            }
        }
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
        switch headingSource {
            case .compassAutomatic(let heading)      : return Float(heading * .pi / 180)
            case .manualCalibration(let calibration) : return calibration.northOffsetRadians
        }
    }
    
    private func fetchTimeZone(for location: CLLocation) async throws -> TimeZone? {
        let request = MKReverseGeocodingRequest(location: CLLocation(latitude:  location.coordinate.latitude, longitude: location.coordinate.longitude))
        return try await request?.mapItems.first?.timeZone
    }
}
