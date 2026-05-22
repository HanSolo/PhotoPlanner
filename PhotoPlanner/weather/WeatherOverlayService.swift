//
//  WeatherOverlay.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//

import Foundation
import WeatherKit
import CoreLocation
import MapKit


actor WeatherOverlayService {

    private let weatherService = WeatherService.shared

    func fetchWeather(at location: CLLocation, on date: Date) async throws -> CachedDailyWeather {
        let timeZone   : TimeZone = try await fetchTimeZone(for: location) ?? .current
        var calendar   : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfDay : Date = calendar.startOfDay(for: date)
        let endOfDay   : Date = startOfDay.addingTimeInterval(86400)

        let forecast   = try await weatherService.weather(for: location, including: .hourly(startDate: startOfDay, endDate: endOfDay))

        let hours : [CachedHourlyWeather] = forecast.forecast
            .filter { $0.date >= startOfDay && $0.date < endOfDay }
            .map { hour in
                CachedHourlyWeather(
                    date                 : hour.date,
                    temperature          : hour.temperature.converted(to: .celsius).value,
                    feelsLike            : hour.apparentTemperature.converted(to: .celsius).value,
                    conditionRawValue    : hour.condition.rawValue,
                    precipitationChance  : hour.precipitationChance,
                    windSpeedKmh         : hour.wind.speed.converted(to: .kilometersPerHour).value,
                    windDirectionDegrees : hour.wind.direction.converted(to: .degrees).value,
                    humidity             : hour.humidity,
                    visibilityKm         : hour.visibility.converted(to: .kilometers).value,
                    uvIndex              : hour.uvIndex.value
                )
            }

        return CachedDailyWeather(
            date               : date,
            coordinate         : CachedDailyWeather.CachedCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            timeZoneIdentifier : timeZone.identifier,
            fetchedAt          : Date(),
            hours              : hours
        )
    }

    private func fetchTimeZone(for location: CLLocation) async throws -> TimeZone? {
        let request = MKReverseGeocodingRequest(
            location: CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        )
        return try await request?.mapItems.first?.timeZone
    }
}
