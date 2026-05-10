//
//  Teleconverter.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 30.04.26.
//

import Foundation


public class Teleconverter {
    
    var factorDidChange : (()->())?
    var lightLoss       : Double { return log2(self.factor * self.factor) }
    var factor          : Double {
     
         didSet {
             if oldValue != self.factor {
                 self.factorDidChange?()
            }
         }
    }
    
    
    init(factor : Double = 1.0) {
        self.factor = factor
    }
        
    
    func effectiveFocalLength(original: Double) -> Double { return original * self.factor }

    func roundedFocalLength(_ mm: Double) -> Double {
        let step : Double = mm < 100 ? 5 : 10
        return (mm / step).rounded() * step
    }
    
    func effectiveAperture(original: Double) -> Double { return original * self.factor }
    
    func roundedAperture(_ f: Double) -> Double {
        let stops   : Double = log2(f)                   // position on the log2 f-stop scale
        let rounded : Double = (stops * 3).rounded() / 3 // snap to nearest 1/3 stop
        return pow(2.0, rounded)
    }
    
    
    struct TcModifiedValues {
        let exactFocalLength   : Double
        let exactAperture      : Double
        let roundedFocalLength : Double
        let roundedAperture    : Double
        let lightLoss          : Double
    }
    
    func calculate(focalLength: Double, aperture: Double) -> TcModifiedValues {
        TcModifiedValues(exactFocalLength: effectiveFocalLength(original: focalLength), exactAperture: effectiveAperture(original: aperture),roundedFocalLength: roundedFocalLength(effectiveFocalLength(original: focalLength)), roundedAperture: roundedAperture(effectiveAperture(original: aperture)), lightLoss: self.lightLoss)
    }
}


/*
let testCases: [(focalLength: Double, aperture: Double, label: String)] = [
    (200, 2.8, "70–200mm f/2.8 @ 200mm"),
    (500, 4.0, "500mm f/4"),
    (85, 1.4, "85mm f/1.4"),
    (300, 2.8, "300mm f/2.8"),
    (35, 1.8, "35mm f/1.8"),
    (1200, 8.0, "1200mm f/8") // extreme case
]

for factor in [1.4, 1.7, 2.0] {
    let tc = Teleconverter(factor: factor)
    print("=== \(factor)× Teleconverter (−\(String(format: "%.2f", tc.lightLoss)) stops) ===")

    for lens in testCases {
        let r = tc.calculate(focalLength: lens.focalLength, aperture: lens.aperture)
        print("\(lens.label)")
        print("\(Exact → \(String(format: "%.1f", r.exactFocalLength))mm f/\(String(format: "%.2f", r.exactAperture)))")
        print("\(Rounded → \(String(format: "%.0f", r.roundedFocalLength))mm f/\(String(format: "%.2f", r.roundedAperture)))")
    }
}
*/
