//
//  ElevationProfile.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import Foundation
import CoreLocation


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
    
    var totalDistance: CLLocationDistance {
        guard let first = points.first, let last = points.last else { return 0 }
        let startLocation : CLLocation = CLLocation(latitude: first.coordinate.latitude, longitude: first.coordinate.longitude)
        let endLocation   : CLLocation = CLLocation(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        return startLocation.distance(from: endLocation)
    }
}
