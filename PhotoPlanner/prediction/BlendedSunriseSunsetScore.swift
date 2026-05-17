//
//  BlendedSunriseSunsetScore.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 17.05.26.
//

import Foundation
import CoreLocation


struct BlendedSunriseSunsetScore {
    /// Score based purely on weather at the camera location
    let cameraLocationScore        : SunriseSunsetScore

    /// Score based on weather at the remote point in the sun's direction
    let remoteLocationScore        : SunriseSunsetScore

    /// Weighted combination of camera and remote scores
    let blendedScore               : SunriseSunsetScore

    /// The coordinate that was sampled for remote weather
    let remoteCoordinate           : CLLocationCoordinate2D

    /// Distance in kilometres between camera and remote point
    let samplingDistanceKilometres : Double
}
