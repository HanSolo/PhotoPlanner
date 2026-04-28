//
//  SpotData.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public struct SpotData: Codable {
    let name          : String?
    let description   : String?
    let lat           : String?
    let lon           : String?
    let countryCode   : String?
    let tags          : String?
    
    
    init(name: String, description: String, lat: String, lon: String, country: String, tags: String) {
        self.name        = name
        self.description = description
        self.lat         = lat
        self.lon         = lon
        self.countryCode = country
        self.tags        = tags
    }
    init(dictionary: Dictionary<String, String>) throws {
        self = try JSONDecoder().decode(SpotData.self, from: JSONSerialization.data(withJSONObject: dictionary))
    }
}
