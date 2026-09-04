//
//  StormCellFeature.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.09.26.
//

import Foundation
import CoreLocation


struct StormCellFeature: Decodable, Identifiable {
    let id         : UUID = UUID()
    let properties : StormCellProperties
    let geometry   : StormCellGeometry

    enum CodingKeys: String, CodingKey {
        case properties, geometry
    }

    var coordinate: CLLocationCoordinate2D {
        // GeoJSON order is [lon, lat]
        CLLocationCoordinate2D(latitude: geometry.coordinates[1], longitude: geometry.coordinates[0])
    }
}
