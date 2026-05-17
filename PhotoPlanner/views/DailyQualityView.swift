//
//  DailyQualityView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation
import SwiftUI


struct DailyQualityView: View {
    let timeline      : DailyQualityTimeline
    private var hourFormatter : DateFormatter {
        let hf : DateFormatter = DateFormatter()
        hf.dateFormat = "HH"
        hf.timeZone   = timeline.timeZone
        return hf
    }

    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {

            // Header
            HStack {
                Text(timeline.date, style: .date)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                
                Spacer()
                
                if let sunrise = timeline.bestSunrise {
                    gradeTag(label: "Rise", slot: sunrise)
                }
                if let sunset = timeline.bestSunset {
                    gradeTag(label: "Set", slot: sunset)
                }
            }

            GeometryReader { geometry in
                Canvas { ctx, size in
                    let slots : [DailyQualityTimeline.HourSlot] = timeline.slots
                    guard !slots.isEmpty, size.width > 0, size.height > 0 else { return }

                    var localCalendar : Calendar = Calendar(identifier: .gregorian)
                    localCalendar.timeZone = timeline.timeZone

                    // Use local hour to position bars rather than slot index
                    // This ensures bars align correctly with the hour labels
                    let startOfDay   : Date    = localCalendar.startOfDay(for: timeline.date)
                    let totalSeconds : CGFloat = 86400
                    
                    for slot in slots {
                        // Position based on seconds elapsed since local midnight
                        let elapsed   : Double  = slot.time.timeIntervalSince(startOfDay)
                        let xFraction : CGFloat = CGFloat(elapsed) / totalSeconds
                        let x         : CGFloat = xFraction * size.width

                        // Bar width based on slot interval (1 hour = 1/24 of width)
                        let barWidth : CGFloat = size.width / 24.0

                        guard slot.isSunUp else {
                            ctx.fill(Path(roundedRect: CGRect(x: x + 1, y: size.height - 3, width: max(1, barWidth - 2), height: 3), cornerRadius: 1), with: .color(.white.opacity(0.08)))
                            continue
                        }

                        guard slot.isGoldenHour else {
                            ctx.fill(Path(roundedRect: CGRect(x: x + 1, y: size.height - 8, width: max(1, barWidth - 2), height: 8), cornerRadius: 1), with: .color(.white.opacity(0.08)))
                            continue
                        }

                        guard let score : SunriseSunsetScore = slot.score else { continue }

                        let fraction  : CGFloat = gradeFraction(score.overall)
                        let barHeight : CGFloat = max(4, (size.height - 4) * fraction)
                        let y         : CGFloat = size.height - barHeight
                        let rect      : CGRect  = CGRect(x: x + 1, y: y, width: max(1, barWidth - 2), height: barHeight)

                        ctx.fill(
                            Path(roundedRect: rect, cornerRadius: 2),
                            with: .linearGradient(
                                Gradient(colors: [score.overall.color.opacity(0.9), score.overall.color.opacity(0.35)]),
                                                  startPoint: CGPoint(x: x, y: y),
                                                  endPoint: CGPoint(x: x, y: size.height)
                            )
                        )

                        let isBest : Bool = slot.id == timeline.bestSunrise?.id || slot.id == timeline.bestSunset?.id
                        if isBest {
                            ctx.fill(Path(ellipseIn: CGRect(x: x + barWidth / 2 - 2.5, y: y - 6, width: 5, height: 5)), with: .color(score.overall.color))
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)

            // Labels for hour of day
            let localCalendar: Calendar = {
                var c      = Calendar(identifier: .gregorian)
                c.timeZone = timeline.timeZone
                return c
            }()
                        
            // Hour labels
            HStack(spacing: 0) {
                ForEach(Array(timeline.slots.enumerated()), id: \.offset) { i, slot in
                    let hour = localCalendar.component(.hour, from: slot.time)
                    Text(hour % 2 == 0 ? String(format: "%02d", hour) : "")
                        .font(.system(size: 7).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
    }
    
    private func gradeTag(label: String, slot: DailyQualityTimeline.HourSlot) -> some View {
        HStack(spacing: 3) {
            Text(label).foregroundStyle(.white.opacity(0.5))
            Text(slot.score?.overall.rawValue ?? "-")
                .foregroundStyle(slot.score?.overall.color ?? .secondary)
                .bold()
        }
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.white.opacity(0.1))
        .clipShape(Capsule())
    }

    private func gradeFraction(_ grade: SunriseSunsetScore.Grade) -> CGFloat {
        switch grade {
        case .poor  : return 0.15
        case .fair  : return 0.35
        case .good  : return 0.58
        case .great : return 0.80
        case .grand : return 1.00
        }
    }
}
