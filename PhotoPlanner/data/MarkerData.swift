//
//  CameraMarkerData.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import SwiftUI
import MapKit


struct MarkerData {
    let touchArea   : CGRect = CGRect(x: 0, y: 0, width: 80, height: 80)
    let coordinate  : CLLocationCoordinate2D
    let screenPoint : CGPoint
    
    var touchableRect: CGRect {
        .init(x: screenPoint.x - touchArea.width / 2, y: screenPoint.y - touchArea.height / 2, width: touchArea.width, height: touchArea.height)
    }
}
