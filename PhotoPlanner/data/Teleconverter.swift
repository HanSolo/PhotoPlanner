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
