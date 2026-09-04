//
//  StormCellProperties.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.09.26.
//

import Foundation


struct StormCellProperties: Decodable {
    let areaKm2          : Double
    let maxDbz           : Double
    let motionSpeedKmh   : Double
    let motionHeadingDeg : Double
    let region           : String?

    
    enum CodingKeys: String, CodingKey {
        case areaKm2          = "area_km2"
        case maxDbz           = "max_dbz"
        case motionSpeedKmh   = "motion_speed_kmh"
        case motionHeadingDeg = "motion_heading_deg"
        case region
    }
}
