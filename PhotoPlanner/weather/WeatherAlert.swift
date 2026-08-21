//
//  WeatherAlert.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.08.26.
//

import Foundation


struct WeatherAlert: Identifiable {
    let id       : String
    let event    : String     // e.g. "Thunderstorm Warning"
    let headline : String
    let severity : AlertSeverity
    let expiry   : Date?
    let sender   : String
 
    var expiryLabel: String {
        guard let expiry else { return "No expiry" }
        let formatter      = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "Until \(formatter.string(from: expiry))"
    }
 
    
    var icon: String {
        let lower = event.lowercased()
        if lower.contains("thunder") || lower.contains("lightning") { return "cloud.bolt.fill" }
        if lower.contains("tornado")                                { return "tornado" }
        if lower.contains("hurricane") || lower.contains("typhoon") { return "hurricane" }
        if lower.contains("wind")                                   { return "wind" }
        if lower.contains("fog")                                    { return "cloud.fog.fill" }
        if lower.contains("snow") || lower.contains("blizzard")     { return "cloud.snow.fill" }
        if lower.contains("ice") || lower.contains("frost")         { return "thermometer.snowflake" }
        if lower.contains("flood")                                  { return "drop.fill" }
        if lower.contains("heat")                                   { return "thermometer.sun.fill" }
        if lower.contains("fire")                                   { return "flame.fill" }
        return "exclamationmark.triangle.fill"
    }
}
