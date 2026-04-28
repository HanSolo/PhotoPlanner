//
//  LensData.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public struct LensData: Codable {
    let name          : String?
    let minFocalLength: String?
    let maxFocalLength: String?
    let minAperture   : String?
    let maxAperture   : String?
    let sensorFormat  : String?
    
    
    init(name: String, minFocalLength: String, maxFocalLength: String, minAperture: String, maxAperture: String, sensorFormat: String) {
        self.name           = name
        self.minFocalLength = minFocalLength
        self.maxFocalLength = maxFocalLength
        self.minAperture    = minAperture
        self.maxAperture    = maxAperture
        self.sensorFormat   = sensorFormat
    }
    init(dictionary: Dictionary<String, String>) throws {
        self = try JSONDecoder().decode(LensData.self, from: JSONSerialization.data(withJSONObject: dictionary))
    }
}
