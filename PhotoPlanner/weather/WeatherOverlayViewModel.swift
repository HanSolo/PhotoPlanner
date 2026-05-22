//
//  WeatherOverlayViewModel.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//


import Foundation
import SwiftUI
import WeatherKit
import CoreLocation
import MapKit


@Observable
class WeatherOverlayViewModel {

    var weather          : CachedDailyWeather?
    var isLoading        : Bool = false
    var isOutdated       : Bool = false
    var isVisible        : Bool = false
    var isVisibleBinding : Binding<Bool> {
        Binding(get: { self.isVisible}, set: { self.isVisible = $0 })
    }
    var error            : Error?

    private let service = WeatherOverlayService()

    
    func fetch(at location: CLLocationCoordinate2D, on date: Date, forceRefresh: Bool = false) async {
        let clLocation : CLLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        // Check cache first
        if !forceRefresh,
           let cached = WeatherCacheStore.load(),
           cached.isValid(for: clLocation, on: date) {
               weather    = cached
               isOutdated = false
               isVisible  = true
               return
           }

        // No valid cache — fetch from WeatherKit
        isLoading = true
        error     = nil

        do {
            let fetched = try await service.fetchWeather(at: clLocation, on: date)
            WeatherCacheStore.save(fetched)
            weather    = fetched
            isOutdated = false
            isVisible  = true
        } catch {
            self.error = error
            // Don't set isVisible, nothing to show if fetch failed
            // But if we have stale cached data, show it anyway with outdated flag
            if let stale = WeatherCacheStore.load() {
                weather    = stale
                isOutdated = true
                isVisible  = true
            }
        }

        isLoading = false
    }

    func checkIfOutdated(for location: CLLocation, on date: Date) {
        guard let cached = weather else { return }
        isOutdated = !cached.isValid(for: location, on: date)
    }

    func dismiss() {
        isVisible = false
    }
}
