//
//  FieldOfViewCalculatorModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.05.26.
//

import Foundation
import SwiftUI


@Observable
class FieldOfViewCalculatorViewModel {
    let focalLength       : Double
    let sensorWidth       : Double
    let sensorHeight      : Double

    var orientation       : CameraOrientation = .landscape
    var fieldWidthSlider  : Double           // 0...1 logarithmic
    var fieldHeightSlider : Double           // 0...1 logarithmic
    var activeAxis        : Axis              = .horizontal

    enum Axis { case horizontal, vertical }

    
    init(focalLength: Double, sensorWidth: Double, sensorHeight: Double) {
        self.focalLength  = focalLength
        self.sensorWidth  = sensorWidth
        self.sensorHeight = sensorHeight

        // Default to 10m field width
        self.fieldWidthSlider  = FieldOfViewCalculator.metresToSlider(10.0)
        self.fieldHeightSlider = FieldOfViewCalculator.metresToSlider(10.0 / (sensorWidth / sensorHeight))
    }
        
    var horizontalFOV: Double {
        return FieldOfViewCalculator.fovAngles(focalLength: focalLength, sensorWidth: sensorWidth, sensorHeight: sensorHeight).horizontal
    }
   
    var verticalFOV: Double {
        return FieldOfViewCalculator.fovAngles(focalLength: focalLength, sensorWidth: sensorWidth, sensorHeight: sensorHeight).vertical
    }
    
    var aspectRatio     : Double {
        orientation == .landscape ? sensorWidth / sensorHeight : sensorHeight / sensorWidth
    }

    var fieldWidth      : Double {
        FieldOfViewCalculator.sliderToMetres(fieldWidthSlider)
    }

    var fieldHeight     : Double {
        FieldOfViewCalculator.sliderToMetres(fieldHeightSlider)
    }
        
    var minimumDistance: Double {
        switch activeAxis {
            case .horizontal : return FieldOfViewCalculator.minimumDistance(fieldSize: fieldWidth, fovAngle: horizontalFOV)
            case .vertical   : return FieldOfViewCalculator.minimumDistance(fieldSize: fieldHeight, fovAngle: verticalFOV)
        }
    }

    
    func widthSliderChanged(to value: Double) {
        self.activeAxis        = .horizontal
        self.fieldWidthSlider  = value
        // Update height to maintain aspect ratio
        let widthMetres   : Double = FieldOfViewCalculator.sliderToMetres(value)
        let heightMetres  : Double = widthMetres / aspectRatio
        fieldHeightSlider = FieldOfViewCalculator.metresToSlider(heightMetres)
    }

    func heightSliderChanged(to value: Double) {
        self.activeAxis        = .vertical
        self.fieldHeightSlider = value
        // Update width to maintain aspect ratio
        let heightMetres  : Double = FieldOfViewCalculator.sliderToMetres(value)
        let widthMetres   : Double = heightMetres * aspectRatio
        fieldWidthSlider  = FieldOfViewCalculator.metresToSlider(widthMetres)
    }

    func orientationChanged(to orientation: CameraOrientation) {
        guard orientation != self.orientation else { return }
        self.orientation = orientation

        // Swap slider values
        let previousWidth  : CGFloat = fieldWidthSlider
        let previousHeight : CGFloat = fieldHeightSlider
        fieldWidthSlider   = previousHeight
        fieldHeightSlider  = previousWidth
        
        activeAxis = .horizontal
    }
}
