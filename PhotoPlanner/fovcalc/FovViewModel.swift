//
//  FovViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.08.26.
//

import Foundation
import SwiftUI


@Observable
class FovViewModel {
    var focalLength        : Double
    var aperture           : Double
    var focusDistance      : Double   // [m]
    var isLandscape        : Bool = true
    let camera             : Camera
    let lens               : Lens
    var sensorFormat       : SensorFormat { SensorFormat.allCases[camera.sensorFormat] }

    var focalLengthRange   : ClosedRange<Double> { lens.minFocalLength...lens.maxFocalLength }
    var apertureRange      : ClosedRange<Double> { lens.minAperture...lens.maxAperture }
    let focusDistanceRange : ClosedRange<Double> = 0.3...100.0
    var dof                : DOFResult {
        calculateDOF(focalLengthMm: focalLength, aperture: aperture, focusDistanceM: focusDistance, sensorFormat: sensorFormat, isLandscape: isLandscape)
    }
    var maxDisplayDistance : Double {  // Maximum Y axis distance — whichever is smaller: hyperfocal or 500m
        min(dof.hyperfocal * 1.2, 100.0)
    }

    
    init(camera: Camera, lens: Lens) {
        self.camera        = camera
        self.lens          = lens
        self.focalLength   = lens.minFocalLength
        self.aperture      = lens.minAperture
        self.focusDistance = 10.0
    }
    
    
    private func calculateDOF(focalLengthMm : Double, aperture : Double, focusDistanceM : Double, sensorFormat : SensorFormat, isLandscape : Bool) -> DOFResult {
        // Sensor dimensions in mm
        let sensorW = isLandscape ? sensorFormat.width  : sensorFormat.height
        let sensorH = isLandscape ? sensorFormat.height : sensorFormat.width

        // Circle of confusion — sensor diagonal / 1500
        let diagonal = (sensorW * sensorW + sensorH * sensorH).squareRoot()
        let coc      = diagonal / 1500.0   // mm

        // Hyperfocal distance in metres
        let hyperfocalMm = (focalLengthMm * focalLengthMm) / (aperture * coc) + focalLengthMm
        let hyperfocalM  = hyperfocalMm / 1000.0

        // Near and far DOF limits in metres
        let f     = focusDistanceM
        let h     = hyperfocalM
        let nearM = (h * f) / (h + f)
        let farM  = f >= h ? Double.infinity : (h * f) / (h - f)

        // Frame size at focus distance
        let hFovRad = 2.0 * atan((sensorW / 2.0) / focalLengthMm)
        let vFovRad = 2.0 * atan((sensorH / 2.0) / focalLengthMm)
        let frameW  = 2.0 * focusDistanceM * tan(hFovRad / 2.0)
        let frameH  = 2.0 * focusDistanceM * tan(vFovRad / 2.0)

        return DOFResult(nearLimit: nearM, farLimit: farM, hyperfocal: hyperfocalM, frameWidthAtFocus: frameW, frameHeightAtFocus: frameH, cocMm: coc)
    }

}
