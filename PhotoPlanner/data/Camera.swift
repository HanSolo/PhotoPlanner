//
//  Camera.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import SwiftData


@Model
public class Camera: Identifiable {
    private(set) public var id  : String
    var name        : String
    var sensorFormat: Int
    
    
    init(name: String, sensorFormat: Int) {
        self.id           = UUID().uuidString
        self.name         = name
        self.sensorFormat = sensorFormat
    }
    
    func description() -> String {
        let format : SensorFormat = SensorFormat.allCases[sensorFormat]
        var description = name
        description += " \(format.name)"
        description += " \(String(format: "%.1f", format.width))"
        description += " mm \(String(format: "%.1f", format.height))"
        description += " mm \(String(format: "%.2f", format.cropFactor))"
        return description
    }

}
