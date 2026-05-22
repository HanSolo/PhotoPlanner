//
//  ExposureCalculatorViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//

import Foundation
import SwiftUI


@Observable
class ExposureCalculatorViewModel {

    // Setup 1: base exposure
    var setup1ApertureIndex : Int
    var setup1ShutterIndex  : Int
    var setup1ISOIndex      : Int

    // Setup 2: filtered shot
    var setup2ApertureIndex : Int
    var setup2ISOIndex      : Int
    var setup2NDStops       : Int

    
    init(baseAperture: Double) {
        let apertureIndex  : Int = PhotoValues.indexOfAperture(baseAperture)
        let defaultShutter : Int = PhotoValues.indexOfShutter(1.0 / 125)
        let defaultISO     : Int = PhotoValues.indexOfISO(64)

        setup1ApertureIndex = apertureIndex
        setup1ShutterIndex  = defaultShutter
        setup1ISOIndex      = defaultISO

        // Setup 2 starts with same values as setup 1
        setup2ApertureIndex = apertureIndex
        setup2ISOIndex      = defaultISO
        setup2NDStops       = 0
    }


    var setup1Aperture             : Double { PhotoValues.apertures[setup1ApertureIndex] }
    var setup1Shutter              : Double { PhotoValues.shutterSpeeds[setup1ShutterIndex] }
    var setup1ISO                  : Int    { PhotoValues.isos[setup1ISOIndex] }

    var setup2Aperture             : Double { PhotoValues.apertures[setup2ApertureIndex] }
    var setup2ISO                  : Int    { PhotoValues.isos[setup2ISOIndex] }

    var baseEV                     : Double {
        ExposureCalculator.exposureValue(aperture: setup1Aperture, shutterSpeed: setup1Shutter, iso: setup1ISO)
    }

    var calculatedShutter          : Double {
        ExposureCalculator.requiredShutterSpeed(baseEV: baseEV, aperture: setup2Aperture, iso: setup2ISO, ndStops: setup2NDStops)
    }

    var calculatedShutterFormatted : String {
        ExposureCalculator.formatCalculatedShutter(calculatedShutter)
    }

    var calculatedShutterColor     : Color  {
        ExposureCalculator.shutterColor(calculatedShutter)
    }

    var stopsDifference            : Double {
        log2(calculatedShutter / setup1Shutter)
    }
}
