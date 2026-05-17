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
    var timeline   : MilkywayTimeline?
    var isLoading  : Bool = false

    func fetch(at coordinate: CLLocationCoordinate2D, on date: Date) async {
        isLoading = true
        timeline  = await MilkywayCalculator.getNightTimeline(at: coordinate, on: date)
        isLoading = false
    }

    func dismiss() { timeline = nil }
}
