//
//  LongExposureViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.05.26.
//

import Foundation
import CoreLocation


@Observable
class LongExposureViewModel {
    var timeline  : LongExposureDailyTimeline?
    var error     : Error?
    var isLoading : Bool   = false

    private let predictor = LongExposurePredictor()

    
    func fetch(at location: CLLocationCoordinate2D, on date: Date, cameraHeading: Double) async {
        isLoading = true
        timeline  = nil
        error     = nil

        do {
            timeline = try await predictor.dailyTimeline(at: location, on: date, cameraHeading: cameraHeading)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func dismiss() { timeline = nil }
}
