//
//  RemoteWeatherConfiguration.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 17.05.26.
//

import Foundation


struct RemoteWeatherConfiguration: Sendable {
    // Near sampling distance in kilometres: the prominent, well lit cloud zone that is most visible in the frame.
    var nearSamplingDistanceKilometres: Double

    // Far sampling distance in kilometres: the gateway zone toward the sun that determines whether light is getting through.
    var farSamplingDistanceKilometres: Double


    nonisolated init(nearSamplingDistanceKilometres: Double = 35.0, farSamplingDistanceKilometres:  Double = 70.0) {
        self.nearSamplingDistanceKilometres = nearSamplingDistanceKilometres
        self.farSamplingDistanceKilometres  = farSamplingDistanceKilometres
    }
}
