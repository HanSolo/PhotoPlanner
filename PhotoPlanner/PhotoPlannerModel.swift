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
public class PhotoPlannerModel {
    
    var camera                 : Camera            = Constants.DEFAULT_CAMERA {
        didSet {
            Properties.instance.cameraId = self.camera.id            
            self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation)
            if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
        }
    }
    var lens                   : Lens              = Constants.DEFAULT_LENS {
        didSet {
            Properties.instance.lensId = self.lens.id
            self.focalLength = self.lens.minFocalLength
            self.aperture    = self.lens.minAperture
            self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation)
            if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
        }
    }
    var orientation            : CameraOrientation = CameraOrientation.landscape
    var focalLength            : Double            = Constants.DEFAULT_LENS.minFocalLength {
        didSet {
            Properties.instance.focalLength = self.focalLength
            self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation)
            if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
        }
    }
    var focalLengthBinding     : Binding<Double> {
        Binding(get: { self.focalLength }, set: { self.focalLength = $0 })
    }
    var aperture               : Double            = Constants.DEFAULT_LENS.minAperture {
        didSet {
            Properties.instance.aperture = self.aperture
            self.updateFoVTriangle(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation)
            if self.dofVisible { self.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.focalLength, aperture: self.aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation) }
        }
    }
    var apertureBinding        : Binding<Double> {
        Binding(get: { self.aperture }, set: { self.aperture = $0 })
    }
    var fovData                : FoVData?
    var cameraMarkerData       : MarkerData?
    var motifMarkerData        : MarkerData?
    var dofVisible             : Bool                     = false
    var dofVisibleBinding      : Binding<Bool> {
        Binding(get: { self.dofVisible}, set: { self.dofVisible = $0 })
    }
    var triangleCoordinates    : [CLLocationCoordinate2D] = []
    var minTriangleCoordinates : [CLLocationCoordinate2D] = []
    var maxTriangleCoordinates : [CLLocationCoordinate2D] = []
    var trapezoidCoordinates   : [CLLocationCoordinate2D] = []    
    

    init() {
        //Task { await requestAuthorization() }
    }
    
    
    func updateFoVTriangle(cameraPoint: MKMapPoint, motifPoint: MKMapPoint, focalLength: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation) -> Void {
        let distance : CLLocationDistance = cameraPoint.distance(to: motifPoint)
        if distance < 0.01 || distance > 9999 { return }
        
        do {
            self.fovData = try Helper.calc(camera: cameraPoint, motif: motifPoint, focalLengthInMM: focalLength, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation)
            //Helper.setInfoLabel(label: distanceLabel!, image: UIImage(systemName: "arrow.up.left.and.arrow.down.right")!, imageColor: Constants.YELLOW, size: CGSize(width: 12, height: 12), text: "Distance: ", value1: fovData?.distance ?? 0, decimals1: 1, unit1: Constants.UNIT_LENGTH)
            //Helper.setInfoLabel(label: widthLabel!, image: UIImage(named: "width.png")!, imageColor: Constants.YELLOW, size: CGSize(width: 12, height: 12), text: "Width: ", value1: fovData?.fovWidth ?? 0, decimals1: 1, unit1: Constants.UNIT_LENGTH, value2: Helper.toDegrees(radians: fovData?.fovWidthAngle ?? 0), decimals2: 1, unit2: Constants.UNIT_ANGLE)
            //Helper.setInfoLabel(label: heightLabel!, image: UIImage(named: "height.png")!, imageColor: Constants.YELLOW, size: CGSize(width: 12, height: 12), text: "Height: ", value1: fovData?.fovHeight ?? 0, decimals1: 1, unit1: Constants.UNIT_LENGTH, value2: Helper.toDegrees(radians: fovData?.fovHeightAngle ?? 0), decimals2: 1, unit2: Constants.UNIT_ANGLE)
        } catch {
            print(error)
        }
                
        // Update FoV Triangle
        let triangleCoordinates : [CLLocationCoordinate2D] = Helper.updateTriangle(camera: cameraPoint, motif: motifPoint, focalLengthInMM: focalLength, aperture: aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation)
        let angleRad            : Double                   = -Helper.toRadians(degrees: Helper.calcBearing(location1: cameraPoint.coordinate, location2: motifPoint.coordinate))
        
        self.triangleCoordinates.removeAll()
        self.triangleCoordinates.append(triangleCoordinates[0])
        self.triangleCoordinates.append(Helper.rotatePointAroundCenter(location: triangleCoordinates[1], around: cameraPoint.coordinate, angleRad: angleRad))
        self.triangleCoordinates.append(Helper.rotatePointAroundCenter(location: triangleCoordinates[2], around: cameraPoint.coordinate, angleRad: angleRad))
                
        
        // Update min FoV Triangle
        let minTriangleCoordinates : [CLLocationCoordinate2D] = Helper.updateTriangle(camera: cameraPoint, motif: motifPoint, focalLengthInMM: self.lens.maxFocalLength, aperture: aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation)
        self.minTriangleCoordinates.removeAll()
        self.minTriangleCoordinates.append(minTriangleCoordinates[0])
        self.minTriangleCoordinates.append(Helper.rotatePointAroundCenter(location: minTriangleCoordinates[1], around: cameraPoint.coordinate, angleRad: angleRad))
        self.minTriangleCoordinates.append(Helper.rotatePointAroundCenter(location: minTriangleCoordinates[2], around: cameraPoint.coordinate, angleRad: angleRad))
        
        // Update max FoV Triangle
        let maxTriangleCoordinates : [CLLocationCoordinate2D] = Helper.updateTriangle(camera: cameraPoint, motif: motifPoint, focalLengthInMM: self.lens.minFocalLength, aperture: aperture, sensorFormat: self.camera.sensorFormat, orientation: self.orientation)
        self.maxTriangleCoordinates.removeAll()
        self.maxTriangleCoordinates.append(maxTriangleCoordinates[0])
        self.maxTriangleCoordinates.append(Helper.rotatePointAroundCenter(location: maxTriangleCoordinates[1], around: cameraPoint.coordinate, angleRad: angleRad))
        self.maxTriangleCoordinates.append(Helper.rotatePointAroundCenter(location: maxTriangleCoordinates[2], around: cameraPoint.coordinate, angleRad: angleRad))
    }
    
    func updateDoFTrapezoid(cameraPoint: MKMapPoint, motifPoint: MKMapPoint, focalLength: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation) -> Void {
        let distance : CLLocationDistance = cameraPoint.distance(to: motifPoint)
        if distance < 0.01 || distance > 9999 { return }
        
        // Update DoF Trapzoid
        let trapezoidCoordinates : [CLLocationCoordinate2D] = Helper.updateTrapezoid(camera: cameraPoint, motif: motifPoint, focalLengthInMM: focalLength, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation)
        let angleRad             : Double                   = -Helper.toRadians(degrees: Helper.calcBearingInDegree(location1: cameraPoint.coordinate, location2: motifPoint.coordinate))
        
        self.trapezoidCoordinates.removeAll()
        self.trapezoidCoordinates.append(Helper.rotatePointAroundCenter(location: trapezoidCoordinates[0], around: cameraPoint.coordinate, angleRad: angleRad))
        self.trapezoidCoordinates.append(Helper.rotatePointAroundCenter(location: trapezoidCoordinates[1], around: cameraPoint.coordinate, angleRad: angleRad))
        self.trapezoidCoordinates.append(Helper.rotatePointAroundCenter(location: trapezoidCoordinates[2], around: cameraPoint.coordinate, angleRad: angleRad))
        self.trapezoidCoordinates.append(Helper.rotatePointAroundCenter(location: trapezoidCoordinates[3], around: cameraPoint.coordinate, angleRad: angleRad))
    }
    
    
    /*
    func requestAuthorization() async {
        do {
            let success = try await HealthKitManager.shared.requestAuthorization()
                self.isAuthorized = success
            if success {
                await fetchAllHealthData()
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    */
}
