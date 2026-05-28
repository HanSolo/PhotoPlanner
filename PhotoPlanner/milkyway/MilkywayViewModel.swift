//
//  MilkywayViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 12.05.26.
//

import Foundation
import CoreLocation
import SwiftUI


@Observable
class MilkywayViewModel {
    var timeline : MilkywayTimeline?

    func fetch(at coordinate: CLLocationCoordinate2D, on date: Date) async {
        timeline  = await MilkywayCalculator.getNightTimeline(at: coordinate, on: date)
    }

    func dismiss() { timeline = nil }
}
