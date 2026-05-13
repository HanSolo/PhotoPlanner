//
//  ElevationProfile.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import Foundation


struct ElevationProfile {
    let points        : [ElevationPoint]
    let cameraHeight  : Double   // meter above ground at start
    let subjectHeight : Double   // meter above ground at end

    var cameraEyeAltitude: Double {
        (points.first?.elevation ?? 0) + cameraHeight
    }

    var subjectAltitude: Double {
        (points.last?.elevation ?? 0) + subjectHeight
    }

    var hasLineOfSight: Bool {
        guard points.count >= 2 else { return true }
        let totalCount : Double = Double(points.count - 1)

        return points.enumerated().allSatisfy { index, point in
            let fraction    : Double = Double(index) / totalCount
            let losAltitude : Double = cameraEyeAltitude + fraction * (subjectAltitude - cameraEyeAltitude)
            return point.elevation <= losAltitude
        }
    }
}
