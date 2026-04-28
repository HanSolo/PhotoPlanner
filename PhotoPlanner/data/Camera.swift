//
//  Camera.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public class Camera: NSObject, NSCoding {
    var name        : String
    var sensorFormat: Int
    
    
    init(name: String, sensorFormat: Int) {
        self.name         = name
        self.sensorFormat = sensorFormat
    }
    public required init?(coder: NSCoder) {
        self.name         = coder.decodeObject(forKey: "name") as? String ?? ""
        self.sensorFormat = coder.decodeInteger(forKey: "sensorFormat")
    }
    
    
    public func encode(with coder: NSCoder) {
        coder.encode(self.name,                forKey: "name")
        coder.encode(self.sensorFormat as Int, forKey: "sensorFormat")
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
    
    
    func toJsonString() -> String {
        let format : SensorFormat = SensorFormat.allCases[sensorFormat]
        var jsonString : String = "{"
        jsonString += "\"name\":\"\(name)\","
        jsonString += "\"sensor\":"
        jsonString += format.jsonString
        jsonString += "}"
        return jsonString
    }
}
