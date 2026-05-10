//
//  PhotoPlannerModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import SwiftUI
import SwiftData
import MapKit


@MainActor @Observable
public class PhotoPlannerModel : NSObject, CLLocationManagerDelegate {
    var locationManager             : CLLocationManager?
    var mapRegion                   : MKCoordinateRegion?
    
    var networkMonitor              : NetworkMonitor           = NetworkMonitor()
    var elevationService            : ElevationService         = ElevationService()
    var camera                      : Camera                   = Constants.DEFAULT_CAMERA {
        didSet {
            Properties.instance.cameraId = self.camera.id            
            self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation, tc1: self.tc1, tc2: self.tc2)
            if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
        }
    }
    var lens                        : Lens                     = Constants.DEFAULT_LENS {
        didSet {
            Properties.instance.lensId = self.lens.id
            self.focalLength    = self.lens.minFocalLength
            self.aperture       = self.lens.minAperture
            self.minAperture    = self.lens.minAperture
            self.maxAperture    = self.lens.maxAperture
            self.minFocalLength = self.lens.minFocalLength
            self.maxFocalLength = self.lens.maxFocalLength
            self.tc1.factor     = 1.0
            self.tc2.factor     = 1.0
            self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation, tc1: self.tc1, tc2: self.tc2)
            if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
            
            updateApertureAndFocalLength()
        }
    }
    var minAperture                 : Double                   = Constants.DEFAULT_LENS.minAperture
    var maxAperture                 : Double                   = Constants.DEFAULT_LENS.maxAperture
    var minFocalLength              : Double                   = Constants.DEFAULT_LENS.minFocalLength
    var maxFocalLength              : Double                   = Constants.DEFAULT_LENS.maxFocalLength
    var orientation                 : CameraOrientation        = CameraOrientation.landscape
    var focalLength                 : Double                   = Constants.DEFAULT_LENS.minFocalLength {
        didSet {
            Properties.instance.focalLength = self.focalLength
            self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation, tc1: self.tc1, tc2: self.tc2)
            if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
        }
    }
    var focalLengthBinding          : Binding<Double> {
        Binding(get: { self.focalLength }, set: { self.focalLength = $0 })
    }
    var aperture                    : Double                   = Constants.DEFAULT_LENS.minAperture {
        didSet {
            Properties.instance.aperture = self.aperture
            self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation, tc1: self.tc1, tc2: self.tc2)
            if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
        }
    }
    var apertureBinding             : Binding<Double> {
        Binding(get: { self.aperture }, set: { self.aperture = $0 })
    }
    var cameraDistance              : Double                   = Properties.instance.distance!
    var cameraDistanceBinding       : Binding<Double> {
        .init(get: { self.cameraDistance }, set: { self.cameraDistance = $0 })
    }
    var fovData                     : FoVData?
    var cameraMarkerData            : MarkerData?
    var motifMarkerData             : MarkerData?
    var currentMapLocation          : CLLocationCoordinate2D?
    var currentMapHeading           : Double?
    var currentMapDate              : Date                     = Date.now
    var currentMapDateBinding       : Binding<Date> {
        .init(get: { self.currentMapDate }, set: { self.currentMapDate = $0 })
    }
    var currentMapStyleIndex        : Int                      = 0
    var currentMapStyleIndexBinding : Binding<Int> {
        Binding(get: { self.currentMapStyleIndex}, set: { self.currentMapStyleIndex = $0 })
    }
    var epdVisible                  : Bool                     = false
    var epdVisibleBinding           : Binding<Bool> {
        Binding(get: { self.epdVisible}, set: { self.epdVisible = $0 })
    }
    var dofVisible                  : Bool                     = false
    var dofVisibleBinding           : Binding<Bool> {
        Binding(get: { self.dofVisible}, set: { self.dofVisible = $0 })
    }
    var triangleCoordinates         : [CLLocationCoordinate2D] = []
    var minTriangleCoordinates      : [CLLocationCoordinate2D] = []
    var maxTriangleCoordinates      : [CLLocationCoordinate2D] = []
    var trapezoidCoordinates        : [CLLocationCoordinate2D] = []
    var metric                      : Bool                     = true
    var magicHours                  : MagicHours               = MagicHours()
    var sunTimes                    : Dictionary<String, Date> = [:]
    var moonTimes                   : Dictionary<String, Date> = [:]
    var tc1                         : Teleconverter            = Teleconverter(factor: Properties.instance.tc1Factor!)
    var tc2                         : Teleconverter            = Teleconverter(factor: Properties.instance.tc2Factor!)
    var elevationProfile            : ElevationProfile?
    

    override init() {
        super.init()
        self.sunTimes  = self.magicHours.getTimes(date: self.currentMapDate, lat: self.currentMapLocation?.latitude ?? 0.0, lon: self.currentMapLocation?.longitude ?? 0.0)
        self.moonTimes = self.magicHours.getMoonTimes(date: self.currentMapDate, lat: self.currentMapLocation?.latitude ?? 0.0, lon: self.currentMapLocation?.longitude ?? 0.0)
        self.tc1.factorDidChange = {
            self.updateApertureAndFocalLength()
        } // listen to changes of tc1 factor
        self.tc2.factorDidChange = {
            self.updateApertureAndFocalLength()
        } // listen to changes of tc2 factor
    }
    
    
    func updateFoVTriangle(cameraPoint: MKMapPoint, motifPoint: MKMapPoint, focalLength: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation, tc1: Teleconverter, tc2: Teleconverter) -> Void {
        let distance : CLLocationDistance = cameraPoint.distance(to: motifPoint)
        if distance < 0.01 || distance > 9999 { return }
        
        do {
            self.fovData = try Helper.calcFoV(camera: cameraPoint, motif: motifPoint, focalLengthInMM: focalLength, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation, tc1: tc1, tc2: tc2)
        } catch {
            debugPrint(error)
        }
                
        // Update FoV Triangle
        let triangleCoordinates : [CLLocationCoordinate2D] = Helper.updateTriangle(camera: cameraPoint, motif: motifPoint, focalLengthInMM: focalLength, aperture: aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation, tc1: self.tc1, tc2: self.tc2)
        let angleRad            : Double                   = -Helper.toRadians(Helper.calcBearing(location1: cameraPoint.coordinate, location2: motifPoint.coordinate))
        
        self.triangleCoordinates.removeAll()
        self.triangleCoordinates.append(triangleCoordinates[0])
        self.triangleCoordinates.append(Helper.rotatePointAroundCenter(location: triangleCoordinates[1], around: cameraPoint.coordinate, angleRad: angleRad))
        self.triangleCoordinates.append(Helper.rotatePointAroundCenter(location: triangleCoordinates[2], around: cameraPoint.coordinate, angleRad: angleRad))
                
        
        // Update min FoV Triangle
        let minTriangleCoordinates : [CLLocationCoordinate2D] = Helper.updateTriangle(camera: cameraPoint, motif: motifPoint, focalLengthInMM: self.lens.maxFocalLength, aperture: aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation, tc1: self.tc1, tc2: self.tc2)
        self.minTriangleCoordinates.removeAll()
        self.minTriangleCoordinates.append(minTriangleCoordinates[0])
        self.minTriangleCoordinates.append(Helper.rotatePointAroundCenter(location: minTriangleCoordinates[1], around: cameraPoint.coordinate, angleRad: angleRad))
        self.minTriangleCoordinates.append(Helper.rotatePointAroundCenter(location: minTriangleCoordinates[2], around: cameraPoint.coordinate, angleRad: angleRad))
        
        // Update max FoV Triangle
        let maxTriangleCoordinates : [CLLocationCoordinate2D] = Helper.updateTriangle(camera: cameraPoint, motif: motifPoint, focalLengthInMM: self.lens.minFocalLength, aperture: aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation, tc1: self.tc1, tc2: self.tc2)
        self.maxTriangleCoordinates.removeAll()
        self.maxTriangleCoordinates.append(maxTriangleCoordinates[0])
        self.maxTriangleCoordinates.append(Helper.rotatePointAroundCenter(location: maxTriangleCoordinates[1], around: cameraPoint.coordinate, angleRad: angleRad))
        self.maxTriangleCoordinates.append(Helper.rotatePointAroundCenter(location: maxTriangleCoordinates[2], around: cameraPoint.coordinate, angleRad: angleRad))
    }    
    
    func updateDoFTrapezoid(cameraPoint: MKMapPoint, motifPoint: MKMapPoint, focalLength: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation) -> Void {
        let distance : CLLocationDistance = cameraPoint.distance(to: motifPoint)
        if distance < 0.01 || distance > 9999 { return }
        
        // Update DoF Trapzoid
        let trapezoidCoordinates : [CLLocationCoordinate2D] = Helper.updateTrapezoid(camera: cameraPoint, motif: motifPoint, focalLengthInMM: focalLength, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation, tc1: self.tc1, tc2: self.tc2)
        let angleRad             : Double                   = -Helper.toRadians(Helper.calcBearingInDegree(location1: cameraPoint.coordinate, location2: motifPoint.coordinate))
        
        self.trapezoidCoordinates.removeAll()
        self.trapezoidCoordinates.append(Helper.rotatePointAroundCenter(location: trapezoidCoordinates[0], around: cameraPoint.coordinate, angleRad: angleRad))
        self.trapezoidCoordinates.append(Helper.rotatePointAroundCenter(location: trapezoidCoordinates[1], around: cameraPoint.coordinate, angleRad: angleRad))
        self.trapezoidCoordinates.append(Helper.rotatePointAroundCenter(location: trapezoidCoordinates[2], around: cameraPoint.coordinate, angleRad: angleRad))
        self.trapezoidCoordinates.append(Helper.rotatePointAroundCenter(location: trapezoidCoordinates[3], around: cameraPoint.coordinate, angleRad: angleRad))
    }
    
    func updateApertureAndFocalLength() -> Void {
        let tc1ModifiedValuesMin : Teleconverter.TcModifiedValues = self.tc1.calculate(focalLength: self.lens.minFocalLength, aperture: self.lens.minAperture)
        let tc1ModifiedValuesMax : Teleconverter.TcModifiedValues = self.tc1.calculate(focalLength: self.lens.maxFocalLength, aperture: self.lens.maxAperture)
        let tc2ModifiedValuesMin : Teleconverter.TcModifiedValues = self.tc2.calculate(focalLength: tc1ModifiedValuesMin.exactFocalLength, aperture: tc1ModifiedValuesMin.exactAperture)
        let tc2ModifiedValuesMax : Teleconverter.TcModifiedValues = self.tc2.calculate(focalLength: tc1ModifiedValuesMax.exactFocalLength, aperture: tc1ModifiedValuesMax.exactAperture)
        
        self.minAperture    = tc2ModifiedValuesMin.exactAperture
        self.maxAperture    = tc2ModifiedValuesMax.exactAperture
        self.minFocalLength = tc2ModifiedValuesMin.exactFocalLength
        self.maxFocalLength = tc2ModifiedValuesMax.exactFocalLength
        
        self.aperture       = self.minAperture
        self.focalLength    = self.minFocalLength
                
        self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation, tc1: self.tc1, tc2: self.tc2)
        if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
    }
    
    func getElevation() async {
        if self.networkMonitor.isConnectedToInternet && self.fovData != nil{
            do {
                self.elevationProfile = try await elevationService.elevationProfile(from: self.fovData!.cameraLocation.coordinate, to: self.fovData!.motifLocation.coordinate, interval: 50, cameraHeight: Constants.DEFAULT_OBSERVER_HEIGHT, motifHeight: 0.0)
            } catch {
                debugPrint("Failed: \(error.localizedDescription)")
            }
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle authorization and update location-related state here, called on main thread.
        // Handle changes in location authorization
        let previousAuthorizationStatus = manager.authorizationStatus
        manager.requestWhenInUseAuthorization()
        if manager.authorizationStatus != previousAuthorizationStatus {
            checkLocationAuthorization()
        }
    }
    
    private func checkLocationAuthorization() {
        // Check location authorization status
        guard let location = self.locationManager else {
            return
        }
        switch location.authorizationStatus {
        case .notDetermined:
            debugPrint("Location authorization is not determined.")
        case .restricted:
            debugPrint("Location is restricted.")
        case .denied:
            debugPrint("Location permission denied.")
        case .authorizedAlways, .authorizedWhenInUse:
            // Update map region with user's location
            if let location = location.location {
                self.mapRegion = MKCoordinateRegion(center: location.coordinate,span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
            }
        default:
            break
        }
    }
    
    func checkIfLocationIsEnabled() {
        if locationManager == nil {
            let manager = CLLocationManager()
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.delegate = self
            self.locationManager = manager
            // Request authorization triggers callback where further handling occurs
            manager.requestWhenInUseAuthorization()
        }
    }
}

