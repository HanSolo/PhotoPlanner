//
//  OpenElevationResponse.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import Foundation
import CoreLocation


struct OpenElevationResponse: Decodable {
    let results: [Result]

    
    struct Result: Decodable {
        let latitude  : Double
        let longitude : Double
        let elevation : Double
    }
}
