//
//  MoonViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.05.26.
//

import Foundation
import SwiftUI
import CoreLocation


@Observable
class MoonViewModel {
    var moonPhase: MoonPhase?

    func fetch(at coordinate: CLLocationCoordinate2D, time: Date,timeZone: TimeZone) {
            moonPhase = MoonCalculator.phase(at: coordinate, time: time, timeZone: timeZone)
        }

    func dismiss() { moonPhase = nil }
}
