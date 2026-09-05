//
//  StormCell.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.09.26.
//

import Foundation
import CoreLocation


class StormCells: Codable {
    var generatedAt : Int?
    var cells       : [Cell]?

    private enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case cells       = "cells"
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try? container.decode(Int.self,    forKey: .generatedAt)
        cells       = try? container.decode([Cell].self, forKey: .cells)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(generatedAt, forKey: .generatedAt)
        try? container.encode(cells,       forKey: .cells)
    }
}

class Cell: Codable, Equatable {
    var lon              : Double?
    var lat              : Double?
    var region           : String?
    var motionSpeedKmh   : Double?
    var motionHeadingDeg : Double?
    var areaKm2          : Double?
    var maxDbz           : Double?

    private enum CodingKeys: String, CodingKey {
        case lon              = "lon"
        case lat              = "lat"
        case region           = "region"
        case motionSpeedKmh   = "motion_speed_kmh"
        case motionHeadingDeg = "motion_heading_deg"
        case areaKm2          = "area_km2"
        case maxDbz           = "max_dbz"
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lon              = try? container.decode(Double.self, forKey: .lon)
        lat              = try? container.decode(Double.self, forKey: .lat)
        region           = try? container.decode(String.self, forKey: .region)
        motionSpeedKmh   = try? container.decode(Double.self, forKey: .motionSpeedKmh)
        motionHeadingDeg = try? container.decode(Double.self, forKey: .motionHeadingDeg)
        areaKm2          = try? container.decode(Double.self, forKey: .areaKm2)
        maxDbz           = try? container.decode(Double.self, forKey: .maxDbz)
    }

    func coordinate() -> CLLocationCoordinate2D {
        guard let latitude : Double = lat, let longitude : Double = lon else { return .init() }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(lon,              forKey: .lon)
        try? container.encode(lat,              forKey: .lat)
        try? container.encode(region,           forKey: .region)
        try? container.encode(motionSpeedKmh,   forKey: .motionSpeedKmh)
        try? container.encode(motionHeadingDeg, forKey: .motionHeadingDeg)
        try? container.encode(areaKm2,          forKey: .areaKm2)
        try? container.encode(maxDbz,           forKey: .maxDbz)
    }
    
    static func == (lhs: Cell, rhs: Cell) -> Bool {
        lhs.lat              == rhs.lat &&
        lhs.lon              == rhs.lon &&
        lhs.motionSpeedKmh   == rhs.motionSpeedKmh &&
        lhs.motionHeadingDeg == rhs.motionHeadingDeg &&
        lhs.areaKm2          == rhs.areaKm2 &&
        lhs.maxDbz           == rhs.maxDbz
    }
}
