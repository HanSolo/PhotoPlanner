//
//  PhotoShoot.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 14.05.26.
//

import Foundation
import CoreLocation
import SwiftData


@Model
public class PhotoShoot {
    private(set) public var id  : String
    
    var name           : String
    var note           : String?
    var camera         : Camera
    var lens           : Lens
    var isLandscape    : Bool
    var aperture       : Double
    var focalLength    : Double
    var tc1            : Double
    var tc2            : Double
    var cameraLat      : Double
    var cameraLon      : Double
    var subjectLat     : Double
    var subjectLon     : Double
    var cameraDistance : Double
    
    
    init(name: String, note: String = "", camera: Camera, lens: Lens, isLandscape: Bool, aperture: Double, focalLength: Double, tc1: Double, tc2: Double, cameraLat: Double, cameraLon: Double, subjectLat: Double, subjectLon: Double, cameraDistance: Double = 1500) {
        self.id             = UUID().uuidString
        self.name           = name
        self.note           = note
        self.camera         = camera
        self.lens           = lens
        self.isLandscape    = isLandscape
        self.aperture       = aperture
        self.focalLength    = focalLength
        self.tc1            = tc1
        self.tc2            = tc2
        self.cameraLat      = cameraLat
        self.cameraLon      = cameraLon
        self.subjectLat     = subjectLat
        self.subjectLon     = subjectLon
        self.cameraDistance = cameraDistance
    }
}
