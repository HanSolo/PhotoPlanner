//
//  RemoteWeatherConfiguration.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 17.05.26.
//

import Foundation


struct RemoteWeatherConfiguration: Sendable {
    /// Distance in kilometres to sample weather in the sun's direction
    var samplingDistanceKilometres: Double

    
    nonisolated init(samplingDistanceKilometres: Double = 100.0) {
        self.samplingDistanceKilometres = samplingDistanceKilometres
    }        
}
