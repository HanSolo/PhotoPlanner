//
//  WeatherOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//


import Foundation
import SwiftUI
import WeatherKit
import CoreLocation
import MapKit

struct WeatherOverlayView: View {
    @State private var scrollOffset : CGFloat = 0
        
    private var localCalendar : Calendar {
        var calendar      : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = weather.timeZone
        return calendar
    }
    private var currentHour   : CachedHourlyWeather? {
        let now : Date = Date()
        return weather.hours.min { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) }
    }
    
    let weather    : CachedDailyWeather
    let isOutdated : Bool
    let onRefresh  : () -> Void
    let onDismiss  : () -> Void

    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .bottom, spacing: 10) {
                // Current conditions
                if let current = currentHour {
                    HStack(spacing: 6) {
                        Image(systemName: current.conditionIcon)
                            .font(.system(size: 22))
                            .foregroundStyle(current.conditionColor)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: "%.0f°C", current.temperature))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                            Text(String(format: "Feels %.0f°C", current.feelsLike))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        Divider()
                            .background(.white.opacity(0.3))
                            .frame(height: 30)

                        // Wind
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 3) {
                                Image(systemName: "wind")
                                    .font(.caption2)
                                Text(String(format: "%.0f km/h", current.windSpeedKmh))
                                    .font(.caption2.monospacedDigit())
                            }
                            .foregroundStyle(.white.opacity(0.7))

                            // Rain chance
                            HStack(spacing: 3) {
                                Image(systemName: "drop.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue.opacity(0.8))
                                Text(String(format: "%.0f%%", current.precipitationChance * 100))
                                    .font(.caption2.monospacedDigit())
                            }
                            .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Outdated indicator + refresh button
                VStack(alignment: .trailing, spacing: 4) {
                    if isOutdated {
                        Button {
                            onRefresh()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9))
                                Text("Outdated")
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    } else {
                        Text(fetchedAtString)
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()
                .background(.white.opacity(0.15))

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(weather.hours, id: \.date) { hour in
                            hourCell(hour: hour)
                                .id(hour.date)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 90)
                .clipped()
                .onAppear {
                    // Scroll to current hour with a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Scroll to 2 hours before current so there's context on the left
                        let targetHour = weather.hours
                            .filter { $0.date <= (currentHour?.date ?? Date()) }
                            .dropLast(2)
                            .last ?? currentHour

                        if let target = targetHour {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(target.date, anchor: .leading)
                            }
                        }
                    }
                }
            }

            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 8))
                Text(locationString)
                    .font(.system(size: 8))
                Spacer()
                Button {
                    onRefresh()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                        Text("Refresh")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            .foregroundStyle(.white.opacity(0.35))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.black.opacity(0.72))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)        
    }


    private func hourCell(hour: CachedHourlyWeather) -> some View {
        let isCurrentHour : Bool = localCalendar.isDate(hour.date, equalTo: Date(), toGranularity: .hour)
        
        return VStack(spacing: 4) {

            // Hour label
            Text(hourString(from: hour.date))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(isCurrentHour ? .white : .white.opacity(0.5))

            // Condition icon
            Image(systemName: hour.conditionIcon)
                .font(.system(size: 16))
                .foregroundStyle(hour.conditionColor)

            // Temperature
            Text(String(format: "%.0f°", hour.temperature))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)

            // Rain probability — only show if > 10%
            if hour.precipitationChance > 0.10 {
                Text(String(format: "%.0f%%", hour.precipitationChance * 100))
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(.blue.opacity(0.8))
            } else {
                Text(" ")
                    .font(.system(size: 8))
            }
        }
        .frame(width: 44)
        .padding(.vertical, 6)
        .background(
            isCurrentHour
                ? RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.12))
                : nil
        )
    }

    
    private func hourString(from date: Date) -> String {
        var calendar      : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone            = weather.timeZone
        let hour          : Int      = calendar.component(.hour, from: date)
        return String(format: "%02d", hour)
    }

    private var fetchedAtString: String {
        let formatter : DateFormatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone  = weather.timeZone
        return "Updated \(formatter.string(from: weather.fetchedAt))"
    }

    private var locationString: String {
        String(format: "%.3f, %.3f", weather.coordinate.latitude, weather.coordinate.longitude)
    }
}
