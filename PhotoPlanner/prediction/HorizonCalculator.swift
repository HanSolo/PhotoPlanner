//
//  HorizonCalculator.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//

import Foundation


struct HorizonCalculator {

    /// Returns the apparent horizon elevation angle (degrees above flat horizon)
    /// in the direction of the elevation profile.
    static func apparentHorizonAngle(from profile: ElevationProfile) -> Double {
        guard let cameraPoint = profile.points.first else { return 0 }
        let cameraAltitude = cameraPoint.elevation + profile.cameraHeight
        var maximumAngle   = 0.0

        for (index, point) in profile.points.dropFirst().enumerated() {
            let fraction           = Double(index + 1) / Double(profile.points.count - 1)
            let horizontalDistance = fraction * profile.totalDistance
            guard horizontalDistance > 0 else { continue }

            let deltaAltitude = point.elevation - cameraAltitude
            let angle         = atan2(deltaAltitude, horizontalDistance) * 180 / .pi
            maximumAngle      = max(maximumAngle, angle)
        }
        return maximumAngle
    }
}
