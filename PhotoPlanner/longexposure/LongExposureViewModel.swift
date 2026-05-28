//
//  LongExposureViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.05.26.
//

import Foundation
import CoreLocation
import SwiftUI


@Observable
class LongExposureViewModel {
    var timeline                   : LongExposureDailyTimeline?
    var error                      : Error?
    var longExposureVisible        : Bool = false
    var longExposureVisibleBinding : Binding<Bool> {
        Binding(get: { self.longExposureVisible}, set: { self.longExposureVisible = $0 })
    }

    private let predictor = LongExposurePredictor()

    
    func fetch(at location: CLLocationCoordinate2D, on date: Date, cameraHeading: Double) async {
        self.timeline = nil
        self.error    = nil

        do {
            self.timeline = try await predictor.dailyTimeline(at: location, on: date, cameraHeading: cameraHeading)
        } catch {
            self.error = error
        }
    }

    func dismiss() {
        self.longExposureVisible = false
        self.timeline            = nil
    }
}
