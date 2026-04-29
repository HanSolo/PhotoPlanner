//
//  Lens.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import SwiftData


@Model
public final class Lens: Identifiable {
    private(set) public var id  : String
    var name          : String
    var minFocalLength: Double
    var maxFocalLength: Double
    var minAperture   : Double
    var maxAperture   : Double
    var sensorFormat  : Int
    var isPrime       : Bool
    
        
    convenience init(name: String="Lens", focalLength: Double, minAperture: Double, maxAperture: Double, sensorFormat: Int) {
        self.init(name: name, minFocalLength: focalLength, maxFocalLength: focalLength, minAperture: minAperture, maxAperture: maxAperture, sensorFormat: sensorFormat)
    }
    init(name: String, minFocalLength: Double, maxFocalLength: Double, minAperture: Double, maxAperture: Double, sensorFormat: Int) {
        self.id             = UUID().uuidString
        self.name           = name
        self.minFocalLength = minFocalLength
        self.maxFocalLength = maxFocalLength
        self.minAperture    = minAperture
        self.maxAperture    = maxAperture
        self.sensorFormat   = sensorFormat
        self.isPrime        = minFocalLength == maxFocalLength
    }
    
    func description() -> String {
        var description = String(format: "%.0f", minFocalLength)
        if isPrime {
            description += " mm f/\(String(format: "%.1f", minAperture))"
            return description
        } else {
            description += " mm - \(String(format: "%.0f", maxFocalLength)) mm f/\(String(format: "%.1f", minAperture))"
            return description
        }
    }
}
