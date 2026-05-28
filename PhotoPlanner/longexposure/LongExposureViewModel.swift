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

    private let predictor = LongExposurePredictor()

    
    func fetch(at location: CLLocationCoordinate2D, on date: Date, cameraHeading: Double) async {
        timeline = nil
        error    = nil

        do {
            timeline = try await predictor.dailyTimeline(at: location, on: date, cameraHeading: cameraHeading)
        } catch {
            self.error = error
        }
    }

    func dismiss() { timeline = nil }
}
