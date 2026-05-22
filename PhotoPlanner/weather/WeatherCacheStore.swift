//
//  WeatherCacheStore.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//


import Foundation

class WeatherCacheStore {

    private static let storageKey : String = "weather_overlay_cache"

    static func save(_ weather: CachedDailyWeather) {
        if let data = try? JSONEncoder().encode(weather) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func load() -> CachedDailyWeather? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let weather = try? JSONDecoder().decode(CachedDailyWeather.self, from: data)
        else { return nil }
        return weather
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
