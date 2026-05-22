//
//  CachedDailyWeather.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//


import Foundation
import SwiftUI
import WeatherKit
import CoreLocation
import MapKit

struct CachedDailyWeather: Codable {
    let date               : Date
    let coordinate         : CachedCoordinate
    let timeZoneIdentifier : String
    let fetchedAt          : Date
    let hours              : [CachedHourlyWeather]
    var timeZone           : TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
    
    
    struct CachedCoordinate: Codable {
        let latitude   : Double
        let longitude  : Double

        var clLocation : CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }
    }

    
    // Cache is valid if location is within 5km and data is less than 3 hours old
    func isValid(for location: CLLocation, on date: Date) -> Bool {
        let cachedLocation : CLLocation = coordinate.clLocation
        let distanceOk     : Bool       = location.distance(from: cachedLocation) <= 5000
        let ageOk          : Bool       = Date().timeIntervalSince(fetchedAt) <= 3 * 3600
        let dateOk         : Bool       = Calendar.current.isDate(self.date, inSameDayAs: date)
        return distanceOk && ageOk && dateOk
    }
}
