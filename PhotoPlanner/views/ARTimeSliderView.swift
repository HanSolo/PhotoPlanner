//
//  ARTimeSliderView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


struct ARTimeSliderView: View {
    @State   private var isDragging   : Bool = false
    @Binding         var selectedTime : Date
        
    let onTimeChanged    : (Date) -> Void
    let onTimeScrubEnded : (Date) -> Void   // rebuild arcs when scrub ends

    private var calendar      : Calendar { Calendar.current }
    private var startOfDay    : Date {
        calendar.startOfDay(for: selectedTime)
    }
    private var fractionOfDay : Double {
        selectedTime.timeIntervalSince(startOfDay) / 86400
    }
    private var timeString    : String {
        let formatter : DateFormatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: selectedTime)
    }
    
    
    var body: some View {
        VStack(spacing: 6) {
            // Time label
            Text(timeString)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)

            // Slider
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)

                    // Golden hour highlights
                    goldenHourHighlights(width: geo.size.width)

                    // Progress fill
                    Capsule()
                        .fill(.clear)
                        .frame(width: geo.size.width * fractionOfDay, height: 4)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .offset(x: geo.size.width * fractionOfDay - 11)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction : Double = max(0, min(1, value.location.x / geo.size.width))
                            let newTime  : Date   = startOfDay.addingTimeInterval(fraction * 86400)
                            selectedTime  = newTime
                            onTimeChanged(newTime)
                        }
                        .onEnded { value in
                            isDragging = false
                            onTimeScrubEnded(selectedTime)
                        }
                )
            }
            .frame(height: 22)

            // Hour labels
            HStack(spacing: 0) {
                ForEach([0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24], id: \.self) { hour in
                    Text(hour == 24 ? "24" : String(format: "%02d", hour))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: hour == 0 ? .leading : hour == 24 ? .trailing : .center)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func goldenHourHighlights(width: CGFloat) -> some View {
        // Approximate golden hour windows as visual hints on the track
        // Sunrise golden hour: ~5 - 7% of day, Sunset: ~78 - 83% of day
        // These are visual hints only, not precise
        let sunriseStart : CGFloat = width * 0.20
        let sunriseEnd   : CGFloat = width * 0.28
        let sunsetStart  : CGFloat = width * 0.75
        let sunsetEnd    : CGFloat = width * 0.83

        Rectangle()
            .fill(Color.orange.opacity(0.6))
            .frame(width: sunriseEnd - sunriseStart, height: 4)
            .offset(x: sunriseStart)

        Rectangle()
            .fill(Color.orange.opacity(0.6))
            .frame(width: sunsetEnd - sunsetStart, height: 4)
            .offset(x: sunsetStart)
    }
}
