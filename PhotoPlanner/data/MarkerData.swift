//
//  CameraMarkerData.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import SwiftUI
import MapKit


struct MarkerData : Equatable {
    let touchArea     : CGRect = CGRect(x: 0, y: 0, width: 80, height: 80)
    var coordinate    : CLLocationCoordinate2D
    var screenPoint   : CGPoint
    var touchableRect : CGRect {
        .init(x: screenPoint.x - touchArea.width / 2, y: screenPoint.y - touchArea.height / 2, width: touchArea.width, height: touchArea.height)
    }
    
    
    static func == (lhs: MarkerData, rhs: MarkerData) -> Bool {
        return lhs.coordinate.latitude  == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
