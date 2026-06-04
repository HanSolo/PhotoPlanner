//
//  LongExposureOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.05.26.
//

import Foundation
import SwiftUI


struct LongExposureOverlayView: View {
    let timeline: LongExposureDailyTimeline

    var body: some View {
        GeometryReader { geometry in
            Canvas { ctx, size in
                drawBackground(ctx: ctx, size: size)
                drawBars(ctx: ctx, size: size)
                drawHourLabels(ctx: ctx, size: size)
                drawBestSlotCallout(ctx: ctx, size: size)
                drawTitle(ctx: ctx, size: size)
            }
            .frame(width: geometry.size.width, height: 160)
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
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
        
    }

    private let leftPadding:   CGFloat = 12
    private let rightPadding:  CGFloat = 12
    private let topPadding:    CGFloat = 28
    private let bottomPadding: CGFloat = 36



    private func drawBackground(ctx: GraphicsContext, size: CGSize) {
        ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14), with: .color(.black.opacity(0.80)))
    }


    private func drawBars(ctx: GraphicsContext, size: CGSize) {
        guard !timeline.slots.isEmpty else { return }

        var localCalendar      : Calendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeline.timeZone
        let startOfDay         : Date     = localCalendar.startOfDay(for: timeline.date)
        let barWidth           : CGFloat  = size.width / 24.0
        let chartHeight        : CGFloat  = size.height - topPadding - bottomPadding

        for slot in timeline.slots {
            let elapsed   : TimeInterval = slot.time.timeIntervalSince(startOfDay)
            let xPosition : CGFloat      = CGFloat(elapsed) / 86400.0 * size.width

            guard slot.isSunUp else {
                ctx.fill(Path(roundedRect: CGRect(x: xPosition + 1, y: size.height - bottomPadding, width: max(1, barWidth - 2), height: 3 ), cornerRadius: 1), with: .color(.white.opacity(0.06)))
                continue
            }

            guard let conditions : LongExposureConditions = slot.conditions else { continue }

            let fraction  : CGFloat = gradeFraction(conditions.overall)
            let barHeight : CGFloat = max(4, chartHeight * fraction)
            let yPosition : CGFloat = size.height - bottomPadding - barHeight
            let barRect   : CGRect  = CGRect(x: xPosition + 1, y: yPosition, width: max(1, barWidth - 2), height: barHeight)

            ctx.fill(
                Path(roundedRect: barRect, cornerRadius: 2),
                with: .linearGradient(
                    Gradient(colors: [conditions.overall.color.opacity(0.9),
                                      conditions.overall.color.opacity(0.3)]),
                    startPoint: CGPoint(x: xPosition, y: yPosition),
                    endPoint:   CGPoint(x: xPosition, y: yPosition + barHeight)
                )
            )

            if slot.id == timeline.bestSlot?.id {
                ctx.fill(Path(ellipseIn: CGRect(x: xPosition + barWidth / 2 - 2.5, y: yPosition - 6, width: 5, height: 5)), with: .color(conditions.overall.color))
            }
        }
    }

    
    private func drawHourLabels(ctx: GraphicsContext, size: CGSize) {
        var localCalendar      : Calendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeline.timeZone
        let startOfDay         : Date     = localCalendar.startOfDay(for: timeline.date)
        let labelY             : CGFloat  = size.height - 14

        for slot in timeline.slots {
            let components : DateComponents = localCalendar.dateComponents([.hour, .minute], from: slot.time)
            guard components.minute == 0, let hour = components.hour, hour % 2 == 0 else { continue }

            let elapsed   : TimeInterval = slot.time.timeIntervalSince(startOfDay)
            let xPosition : CGFloat      = CGFloat(elapsed) / 86400.0 * size.width

            ctx.draw(
                Text(String(format: "%02d", hour))
                    .font(.system(size: 7).monospacedDigit())
                    .foregroundStyle(.white.opacity(slot.isSunUp ? 0.5 : 0.2)),
                at: CGPoint(x: xPosition, y: labelY),
                anchor: .center
            )
        }
    }

    
    private func drawBestSlotCallout(ctx: GraphicsContext, size: CGSize) {
        guard let best = timeline.bestSlot, let conditions : LongExposureConditions = best.conditions else { return }

        ctx.draw(
            Text("Best: \(conditions.recommendedExposure.rawValue) · \(conditions.windCloudAlignment.rawValue) wind")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.55)),
            at: CGPoint(x: size.width / 2, y: size.height - 24),
            anchor: .center
        )
    }

    
    private func drawTitle(ctx: GraphicsContext, size: CGSize) {
        ctx.draw(
            Text("B&W LONG EXPOSURE")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .kerning(1.2),
            at: CGPoint(x: size.width / 2, y: 14),
            anchor: .center
        )
    }

    private func gradeFraction(_ grade: LongExposureConditions.Grade) -> CGFloat {
        switch grade {
            case .poor  : return 0.15
            case .fair  : return 0.35
            case .good  : return 0.58
            case .great : return 0.80
            case .grand : return 1.00
        }
    }
}
