//
//  WindSample.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.08.26.
//
import Foundation


struct WindSample: Sendable {
    let latitude  : Double
    let longitude : Double
    let hourly    : [WindHour]   // all available hours from Open-Meteo
 
    func wind(at date: Date) -> WindHour? {
        guard !hourly.isEmpty else { return nil }
        // Find the closest hourly value to the requested date
        return hourly.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) })
    }
}
