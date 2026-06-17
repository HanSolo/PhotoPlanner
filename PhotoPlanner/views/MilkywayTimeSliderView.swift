//
//  MilkywayTimeSliderView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 16.06.26.
//


import Foundation
import SwiftUI
import CoreLocation

struct MilkywayTimeSliderView: View {
    
    @Binding var selectedTime : Date
    let viewModel             : MilkywayMapViewModel
    let clarityViewModel      : MilkywaySkyClarityViewModel
    
    
    private var startOfDay    : Date {
        var calendar : Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = viewModel.timeZone
        return calendar.startOfDay(for: selectedTime)
    }
    private var fractionOfDay : Double {
        selectedTime.timeIntervalSince(startOfDay) / 86400
    }

    
    var body: some View {
        VStack(spacing: 6) {
            // Time label
            Text(timeString)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)

            // Slider track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Base track
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)

                    // Astronomical darkness highlight
                    if viewModel.darknessWindow.hasDarkness,
                       let startFrac : Double = viewModel.darknessWindow.startFraction(relativeTo: startOfDay),
                       let endFrac   : Double = viewModel.darknessWindow.endFraction(relativeTo: startOfDay) {
                        let trackWidth  : CGFloat = geo.size.width
                        let startX      : CGFloat = trackWidth * startFrac
                        let windowWidth : CGFloat = trackWidth * (endFrac - startFrac)

                        if windowWidth > 0 {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.0, blue: 0.6).opacity(0.8),
                                            Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.9),
                                            Color(red: 0.3, green: 0.0, blue: 0.6).opacity(0.8)
                                        ],
                                        startPoint: .leading,
                                        endPoint:   .trailing
                                    )
                                )
                                .frame(width: max(0, windowWidth), height: 4)
                                .offset(x: startX)
                        }
                    }

                    // Progress fill
                    Capsule()
                        .fill(.white.opacity(0.4))
                        .frame(width: geo.size.width * CGFloat(fractionOfDay), height: 4)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .offset(x: geo.size.width * CGFloat(fractionOfDay) - 11)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction : Double = max(0, min(1, value.location.x / geo.size.width))
                            let newTime  : Date   = startOfDay.addingTimeInterval(fraction * 86400)

                            // Clamp to the available position range
                            if let firstTime : Date = viewModel.positions.first?.time,
                               let lastTime  : Date = viewModel.positions.last?.time {
                                viewModel.selectedTime = min(max(newTime, firstTime), lastTime)
                            } else {
                                viewModel.selectedTime = newTime
                            }
                        }
                )
            }
            .frame(height: 22)

            // Hour labels
            HStack(spacing: 0) {
                ForEach([0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24], id: \.self) { hour in
                    Text(hour == 24 ? "24" : String(format: "%02d", hour))
                        .font(.system(size: 8).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(
                            maxWidth: .infinity,
                            alignment: hour == 0 ? .leading : hour == 24 ? .trailing : .center
                        )
                }
            }

            SkyClarityBar(clarityViewModel: clarityViewModel, startOfDay: startOfDay)
            
            // Darkness window label
            if viewModel.darknessWindow.hasDarkness,
               let start : Date = viewModel.darknessWindow.start,
               let end   : Date = viewModel.darknessWindow.end {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.6, green: 0.3, blue: 1.0))
                        .frame(width: 6, height: 6)
                    Text("Astronomical darkness: \(shortTime(start)) – \(shortTime(end))")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                }
            } else {
                Text("No astronomical darkness tonight")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            if let coord = viewModel.coordinate {
                clarityViewModel.loadClarity(at: coord, on: viewModel.selectedTime, timeZone: viewModel.timeZone)
            }
        }
    }

    private var timeString: String {
        let formatter       : DateFormatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone  = viewModel.timeZone
        return formatter.string(from: selectedTime)
    }

    private func shortTime(_ date: Date) -> String {
        let formatter : DateFormatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone   = viewModel.timeZone
        return formatter.string(from: date)
    }
}
