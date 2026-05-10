//
//  Storage.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//  Copyright © 2026 Gerrit Grunwald. All rights reserved.
//

import Foundation
import SwiftUI
import MapKit


extension Key {
    static let cameraLatitude  : Key = "cameraLatitude"
    static let cameraLongitude : Key = "cameraLongitude"
    static let motifLatitude   : Key = "motifLatitude"
    static let motifLongitude  : Key = "motifLongitude"
    static let lensId          : Key = "lensId"
    static let cameraId        : Key = "cameraId"
    static let aperture        : Key = "aperture"
    static let focalLength     : Key = "focalLength"
    static let distance        : Key = "distance"
    static let tc1Factor       : Key = "tc1Factor"
    static let tc2Factor       : Key = "tc2Factor"
}



// Define storage
public struct Properties {
    
    static var instance = Properties()
    
    @UserDefault(key: .cameraLatitude, defaultValue: Constants.DEFAULT_LOCATION.coordinate.latitude)
    var cameraLatitude: Double?
    
    @UserDefault(key: .cameraLongitude, defaultValue: Constants.DEFAULT_LOCATION.coordinate.longitude)
    var cameraLongitude: Double?
    
    @UserDefault(key: .motifLatitude, defaultValue: Constants.DEFAULT_LOCATION.coordinate.latitude)
    var motifLatitude: Double?
    
    @UserDefault(key: .motifLongitude, defaultValue: Constants.DEFAULT_LOCATION.coordinate.longitude)
    var motifLongitude: Double?
        
    @UserDefault(key: .cameraId, defaultValue: "")
    var cameraId: String?
    
    @UserDefault(key: .lensId, defaultValue: "")
    var lensId: String?
    
    @UserDefault(key: .aperture, defaultValue: 2.8)
    var aperture: Double?
    
    @UserDefault(key: .focalLength, defaultValue: 24)
    var focalLength: Double?
    
    @UserDefault(key: .distance, defaultValue: 1500)
    var distance: Double?
    
    @UserDefault(key: .tc1Factor, defaultValue: 1.0)
    var tc1Factor: Double?
    
    @UserDefault(key: .tc2Factor, defaultValue: 1.0)
    var tc2Factor: Double?
    
    
    
    private init() {}
}
