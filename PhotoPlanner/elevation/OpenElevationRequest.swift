//
//  OpenElevationRequest.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import Foundation
import CoreLocation


struct OpenElevationRequest: Encodable {
    let locations: [Location]

 
    struct Location: Encodable {
        let latitude  : Double
        let longitude : Double
    }
}
