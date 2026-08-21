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
    @State private var scrollOffset : CGFloat             = 0
    @State private var showClouds   : Bool                = false
    @State private var showAlerts   : Bool                = false
    @State private var alertFetcher : WeatherAlertFetcher = WeatherAlertFetcher()

    private var localCalendar : Calendar {
        var calendar : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = weather.timeZone
        return calendar
    }

    private var currentHour   : CachedHourlyWeather? {
        let now : Date = Date()
        return weather.hours.min { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) }
    }

    let viewModel  : WeatherOverlayViewModel
    let weather    : CachedDailyWeather
    let isOutdated : Bool
    let onRefresh  : () -> Void
    let onDismiss  : () -> Void


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Current conditions
            if let current = currentHour {
                HStack(alignment: .bottom, spacing: 10) {
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

                        // Wind + Rain
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 3) {
                                Image(systemName: "wind")
                                    .font(.caption2)
                                Text("\(String(format: "%.0f", current.windSpeedKmh)) km/h")
                                    .font(.caption2.monospacedDigit())
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            HStack(spacing: 3) {
                                Image(systemName: "location")
                                    .font(.caption2)
                                Text(current.windDirectionLabel)
                                    .font(.caption2)
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

                Spacer()

                // Outdated indicator and refresh button
                VStack(alignment: .trailing, spacing: 4) {
                    // Alert icon only visible when alerts exist
                    if !alertFetcher.alerts.isEmpty {
                        Button {
                            showAlerts = true
                        } label: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(alertFetcher.alerts.first?.severity.color ?? .yellow)
                        }
                        .popover(isPresented: $showAlerts) {
                            AlertsPopoverView(alerts: alertFetcher.alerts)
                        }
                    }

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
            .padding(.bottom, 6)

            // Photographer metrics
            photographerMetricsRow(current: current)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }

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

            // Bottom row: location and buttons
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
                Text(locationString)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                if let coord = viewModel.coordinate {
                    Button { showClouds = true } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "dot.radiowaves.up.forward")
                                .font(.system(size: 9))
                            Text("Weather Map")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .sheet(isPresented: $showClouds) {
                        CloudMapView(coordinate: coord)
                    }
                }

                Spacer()

                Button { onRefresh() } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                        Text("Refresh")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.80))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
        .task {
            if let coordinate = viewModel.coordinate {
                await alertFetcher.fetchIfNeeded(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        }
    }


    @ViewBuilder
    private func photographerMetricsRow(current: CachedHourlyWeather) -> some View {
        HStack(spacing: 0) {
            metricPill(icon: "thermometer.medium", label: "Dew Pt", value: String(format: "%.0f°C", current.dewPoint), color: current.condensationRisk ? .orange : .white.opacity(0.7), warning: current.condensationRisk)

            metricDivider()

            metricPill(icon: "humidity", label: "Humidity", value: String(format: "%.0f%%", current.humidity * 100), color: humidityColor(current.humidity))

            metricDivider()

            metricPill(icon: "eye", label: "Visibility", value: current.visibilityKm >= 10 ? String(format: "%.0f km", current.visibilityKm) : String(format: "%.1f km", current.visibilityKm), color: visibilityColor(current.visibilityKm))

            metricDivider()

            metricPill(icon: "sun.max", label: "UV", value: "\(current.uvIndex) · \(current.uvIndexLabel)", color: current.uvIndexColor)
        }
        .padding(.vertical, 6)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func metricPill(icon: String, label: String, value: String, color: Color, warning: Bool = false) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                if warning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.orange)
                }
            }
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func metricDivider() -> some View {
        Divider()
            .background(.white.opacity(0.15))
            .frame(height: 28)
    }


    private func hourCell(hour: CachedHourlyWeather) -> some View {
        let isCurrentHour = localCalendar.isDate(hour.date, equalTo: Date(), toGranularity: .hour)

        return VStack(spacing: 4) {
            Text(hourString(from: hour.date))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(isCurrentHour ? .white : .white.opacity(0.5))

            Image(systemName: hour.conditionIcon)
                .font(.system(size: 16))
                .foregroundStyle(hour.conditionColor)

            Text(String(format: "%.0f°", hour.temperature))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)

            if hour.precipitationChance > 0.10 {
                Text(String(format: "%.0f%%", hour.precipitationChance * 100))
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(.blue.opacity(0.8))
            } else {
                Text(" ").font(.system(size: 8))
            }
        }
        .frame(width: 44)
        .padding(.vertical, 6)
        .background(isCurrentHour ? RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.12)) : nil)
    }


    private func humidityColor(_ humidity: Double) -> Color {
        switch humidity {
            case ..<0.4     : return .white.opacity(0.7)
            case 0.4..<0.7  : return .white.opacity(0.7)
            case 0.7..<0.85 : return .orange
            default         : return .red.opacity(0.8)
        }
    }

    private func visibilityColor(_ km: Double) -> Color {
        switch km {
            case ..<2   : return .red.opacity(0.8)
            case 2..<5  : return .orange
            case 5..<10 : return .yellow.opacity(0.8)
            default     : return .white.opacity(0.7)
        }
    }

    private func hourString(from date: Date) -> String {
        var calendar : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = weather.timeZone
        return String(format: "%02d", calendar.component(.hour, from: date))
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
