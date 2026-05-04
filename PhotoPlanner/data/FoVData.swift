//
//  FoVData.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import MapKit


public class FoVData {
    public let cameraLocation            : MKMapPoint
    public let motifLocation             : MKMapPoint
    public let focalLength               : Double
    public let aperture                  : Double
    public let distance                  : Double
    public let sensorFormat              : Int
    public let orientation               : CameraOrientation
    public let infinite                  : Bool
    public let hyperFocal                : Double
    public let nearLimit                 : Double
    public let farLimit                  : Double
    public let frontPercent              : Double
    public let behindPercent             : Double
    public let total                     : Double
    public let diagonalAngle             : Double
    public let diagonalLength            : Double
    public let fovWidth                  : Double
    public let fovWidthAngle             : Double
    public let fovHeight                 : Double
    public let fovHeightAngle            : Double
    public let radius                    : Double
    public let angleBetweenCameraAndMotif: Double
    public let dofInFront                : Double
    public let dofBehind                 : Double
    
    
    init(camera: MKMapPoint, motif: MKMapPoint, focalLength: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation,
         infinite: Bool, hyperFocal: Double, nearLimit: Double, farLimit: Double, frontPercent: Double, behindPercent: Double, total: Double,
         diagonalAngle: Double, diagonalLength: Double, fovWidth: Double, fovWidthAngle: Double, fovHeight: Double, fovHeightAngle: Double, radius: Double) {
        self.cameraLocation             = camera
        self.motifLocation              = motif
        self.focalLength                = focalLength
        self.aperture                   = aperture
        self.distance                   = camera.distance(to: motif)
        self.sensorFormat               = sensorFormat
        self.orientation                = orientation
        self.infinite                   = infinite
        self.hyperFocal                 = hyperFocal
        self.nearLimit                  = nearLimit
        self.farLimit                   = infinite ? 10000 : farLimit
        self.frontPercent               = frontPercent
        self.behindPercent              = behindPercent
        self.total                      = infinite ? 10000 : total
        self.diagonalAngle              = diagonalAngle
        self.diagonalLength             = diagonalLength
        self.fovWidth                   = fovWidth
        self.fovWidthAngle              = fovWidthAngle
        self.fovHeight                  = fovHeight
        self.fovHeightAngle             = fovHeightAngle
        self.radius                     = radius
        self.angleBetweenCameraAndMotif = Helper.toRadians(Helper.calcBearingInDegree(location1: camera.coordinate, location2: motif.coordinate))
        self.dofInFront                 = distance - nearLimit
        self.dofBehind                  = infinite ? 10000 : farLimit - distance
    }
    
    public func toString() -> String {
        return """
            Sensor      : \(SensorFormat.allCases[Int(sensorFormat)].name) 
            Focal length: \(String(format: "%.0f", focalLength)) mm 
            Aperture    : \(String(format: "%.1f", aperture)) 
            Orientation : \(orientation.name) 
            ----------------------------- 
            Distance    : \(String(format: "%.2f", distance)) m 
            FoV width   : \(String(format: "%.2f", fovWidth)) m (\(String(format: "%.2f", fovWidthAngle)) \u{00b0}) 
            FoV height  : \(String(format: "%.2f", fovHeight)) m (\(String(format: "%.2f", fovHeightAngle)) \u{00b0}) 
            ----------------------------- 
            Hyperfocal  : \(String(format: "%.2f", hyperFocal)) m 
            Near limit  : \(String(format: "%.2f", nearLimit)) m 
            Far  limit  : \(String(format: "%.2f", farLimit)) m 
            In front    : \(String(format: "%.2f", dofInFront)) m 
            Behind      : \(String(format: "%.2f", dofBehind)) m 
            Total       : \(String(format: "%.2f", total)) m 
            -----------------------------
        """
    }
}
