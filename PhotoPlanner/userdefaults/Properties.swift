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
    static let lastLatitude  : Key = "lastLatitude"
    static let lastLongitude : Key = "lastLongitude"
    
}



// Define storage
public struct Properties {
    
    static var instance = Properties()
    
    @UserDefault(key: .lastLatitude, defaultValue: Constants.DEFAULT_LOCATION.coordinate.latitude)
    var lastLatitude: Double?
    
    @UserDefault(key: .lastLongitude, defaultValue: Constants.DEFAULT_LOCATION.coordinate.longitude)
    var lastLongitude: Double?
        
    
    private init() {}
}
