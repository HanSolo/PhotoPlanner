//
//  CachedHourlyWeather.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//


import Foundation
import SwiftUI
import WeatherKit


struct CachedHourlyWeather: Codable {
    let date                 : Date
    let temperature          : Double // °C
    let feelsLike            : Double // °C
    let conditionRawValue    : String // WeatherCondition raw string
    let precipitationChance  : Double // 0.0...1.0
    let windSpeedKmh         : Double
    let windDirectionDegrees : Double
    let humidity             : Double // 0.0...1.0
    let visibilityKm         : Double
    let uvIndex              : Int
    var condition            : WeatherCondition? {
        WeatherCondition(rawValue: conditionRawValue)
    }
    var conditionIcon        : String {
        switch conditionRawValue {
            case "clear", "mostlyClear"          : return "sun.max.fill"
            case "partlyCloudy"                  : return "cloud.sun.fill"
            case "mostlyCloudy"                  : return "cloud.fill"
            case "cloudy"                        : return "cloud.fill"
            case "foggy"                         : return "cloud.fog.fill"
            case "haze"                          : return "sun.haze.fill"
            case "smoky"                         : return "smoke.fill"
            case "blowingDust"                   : return "sun.dust.fill"
            case "drizzle", "freezingDrizzle"    : return "cloud.drizzle.fill"
            case "rain"                          : return "cloud.rain.fill"
            case "heavyRain"                     : return "cloud.heavyrain.fill"
            case "sunShowers"                    : return "cloud.sun.rain.fill"
            case "isolatedThunderstorms",
                 "scatteredThunderstorms",
                 "thunderstorms", "strongStorms" : return "cloud.bolt.rain.fill"
            case "snow", "heavySnow"             : return "cloud.snow.fill"
            case "flurries", "sunFlurries"       : return "cloud.snow.fill"
            case "sleet", "freezingRain",
                 "wintryMix"                     : return "cloud.sleet.fill"
            case "blizzard", "blowingSnow"       : return "wind.snow"
            case "hail"                          : return "cloud.hail.fill"
            case "hot"                           : return "thermometer.sun.fill"
            case "frigid"                        : return "thermometer.snowflake"
            case "tropicalStorm", "hurricane"    : return "tropicalstorm"
            default                              : return "cloud.fill"
        }
    }
    var conditionColor       : Color {
        switch conditionRawValue {
            case "clear", "mostlyClear"                      : return .yellow
            case "partlyCloudy"                              : return .orange.opacity(0.8)
            case "mostlyCloudy", "cloudy"                    : return .gray
            case "foggy", "haze"                             : return .gray.opacity(0.7)
            case "drizzle", "rain"                           : return .blue.opacity(0.7)
            case "heavyRain"                                 : return .blue
            case "snow", "heavySnow", "flurries", "blizzard" : return .white
            case "thunderstorms", "strongStorms"             : return .purple
            default                                          : return .gray
        }
    }
}
