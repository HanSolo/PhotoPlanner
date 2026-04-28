//
//  CameraData.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public struct CameraData: Codable {
    let name          : String?
    let sensorFormat  : String?
    
    
    init(name: String, sensorFormat: String) {
        self.name         = name
        self.sensorFormat = sensorFormat
    }
    init(dictionary: Dictionary<String, String>) throws {
        self = try JSONDecoder().decode(CameraData.self, from: JSONSerialization.data(withJSONObject: dictionary))
    }
}
