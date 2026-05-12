//
//  SunQualityViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation
import CoreLocation
import SwiftUI


@Observable
class SunQualityViewModel {
    var dailyTimeline : DailyQualityTimeline?
    var isLoading     : Bool  = false
    var error         : Error?
    var isVisible     : Bool  = false

    private let predictor = SunriseSunsetPredictor()

    
    func fetch(at location: CLLocationCoordinate2D, on date: Date, shootAzimuth: Double, sunPos: SunPos) async {
        isLoading     = true
        dailyTimeline = nil
        error         = nil

        do {
            dailyTimeline = try await predictor.getDailyTimeline(at: location, on: date, shootAzimuth: shootAzimuth, sunPos: sunPos)
            isVisible = true
        } catch {
            self.error = error
            isVisible  = false
        }

        isLoading = false
    }

    func dismiss() {
        dailyTimeline = nil
        isVisible     = false
    }
}
