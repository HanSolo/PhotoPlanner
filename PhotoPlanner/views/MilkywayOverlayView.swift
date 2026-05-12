//
//  MilkywayPosition.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 12.05.26.
//

import Foundation
import SwiftUI
import CoreLocation


struct MilkywayOverlayView: View {
    let timeline: MilkywayTimeline

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    

    var body: some View {
        GeometryReader { geometry in
            Canvas { ctx, size in
                drawBackground(ctx: ctx, size: size)
                drawArcChart(ctx: ctx, size: size)
                drawHorizonLine(ctx: ctx, size: size)
                drawPeakCallout(ctx: ctx, size: size)
                drawWindowLabels(ctx: ctx, size: size)
                drawHourLabels(ctx: ctx, size: size)
                drawTitle(ctx: ctx, size: size)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(.black.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
            
        }
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
    }

    
    private func drawBackground(ctx: GraphicsContext, size: CGSize) {
        // Deep navy base
        ctx.fill(
            Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14),
            with: .color(Color(red: 0.03, green: 0.03, blue: 0.12))
        )

        // Subtle star field
        let starPositions: [(CGFloat, CGFloat, CGFloat)] = [
            (20, 30, 1.2), (45, 15, 0.8), (80, 40, 1.0), (120, 20, 1.5),
            (160, 35, 0.9), (200, 18, 1.1), (240, 45, 0.7), (270, 25, 1.3),
            (35, 70, 0.8), (95, 55, 1.0), (145, 65, 1.2), (185, 50, 0.9),
            (225, 72, 1.1), (260, 58, 0.8), (285, 42, 1.4)
        ]
        for (x, y, r) in starPositions {
            ctx.fill(Path(ellipseIn: CGRect(x: x - r/2, y: y - r/2, width: r, height: r)), with: .color(.white.opacity(Double.random(in: 0.4...0.9))))
        }

        // Top strip colour based on peak quality
        //let stripColor = timeline.peakSlot?.quality.color ?? .gray
        //ctx.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: 3), cornerRadius: 0), with: .color(stripColor.opacity(0.9)))
    }

    private func drawArcChart(ctx: GraphicsContext, size: CGSize) {
        guard !timeline.slots.isEmpty else { return }

        let slots       : [MilkywayPosition] = timeline.slots
        let leftPad     : CGFloat            = 12
        let rightPad    : CGFloat            = 12
        let topPad      : CGFloat            = 28
        let bottomPad   : CGFloat            = 36
        let chartWidth  : CGFloat            = size.width  - leftPad - rightPad
        let chartHeight : CGFloat            = size.height - topPad  - bottomPad

        func x(for index: Int) -> CGFloat {
            leftPad + CGFloat(index) / CGFloat(slots.count - 1) * chartWidth
        }

        // Map altitude to y — 0° at bottom, 90° at top
        // Clamp to -10° (just below horizon) to 60° max
        func y(for altitude: Double) -> CGFloat {
            let clamped    : Double = max(-10.0, min(60.0, altitude))
            let normalized : Double = (clamped + 10) / 70   // 0–1
            return topPad + chartHeight - normalized * chartHeight
        }

        // Fill area under the curve — only when visible
        var fillPath  : Path = Path()
        var inVisible : Bool = false

        for (i, slot) in slots.enumerated() {
            let px : Double = x(for: i)
            let py : Double = y(for: slot.coreAltitude)

            if slot.isVisible {
                if !inVisible {
                    fillPath.move(to: CGPoint(x: px, y: y(for: 0)))
                    fillPath.addLine(to: CGPoint(x: px, y: py))
                    inVisible = true
                } else {
                    fillPath.addLine(to: CGPoint(x: px, y: py))
                }
            } else if inVisible {
                fillPath.addLine(to: CGPoint(x: px, y: y(for: 0)))
                inVisible = false
            }
        }

        ctx.fill(fillPath, with: .linearGradient(Gradient(colors: [Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.6), Color(red: 0.2, green: 0.1, blue: 0.5).opacity(0.1)]),
                                                 startPoint: CGPoint(x: size.width / 2, y: topPad),
                                                 endPoint  : CGPoint(x: size.width / 2, y: topPad + chartHeight)
        ))

        // Stroke the full altitude curve
        var strokePath : Path = Path()
        for (i, slot) in slots.enumerated() {
            let point : CGPoint = CGPoint(x: x(for: i), y: y(for: slot.coreAltitude))
            if i == 0 {
                strokePath.move(to: point)
            } else {
                strokePath.addLine(to: point)
            }
        }
        ctx.stroke(strokePath, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Visible portion stroke — brighter
        var visiblePath : Path = Path()
        var started     : Bool = false
        for (i, slot) in slots.enumerated() where slot.isVisible {
            let point : CGPoint = CGPoint(x: x(for: i), y: y(for: slot.coreAltitude))
            if !started {
                visiblePath.move(to: point); started = true
            } else {
                visiblePath.addLine(to: point)
            }
        }
        ctx.stroke(visiblePath, with: .linearGradient(Gradient(colors: [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.8, green: 0.6, blue: 1.0)]),
                                                      startPoint: CGPoint(x: 0,          y: topPad),
                                                      endPoint  : CGPoint(x: size.width, y: topPad)
            ),lineWidth: 2
        )
    }

    private func drawHorizonLine(ctx: GraphicsContext, size: CGSize) {
        let leftPad     : CGFloat = 12
        let rightPad    : CGFloat = 12
        let topPad      : CGFloat = 28
        let bottomPad   : CGFloat = 36
        let chartHeight : CGFloat = size.height - topPad - bottomPad
        // y position for 0° altitude
        let horizonY    : CGFloat = topPad + chartHeight - (10.0 / 70.0 * chartHeight)

        var line : Path = Path()
        line.move(to:    CGPoint(x: leftPad,               y: horizonY))
        line.addLine(to: CGPoint(x: size.width - rightPad, y: horizonY))
        ctx.stroke(line, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        ctx.draw(Text("0°").font(.system(size: 7)).foregroundStyle(.white.opacity(0.4)), at: CGPoint(x: leftPad - 4, y: horizonY), anchor: .trailing )
    }

    private func drawPeakCallout(ctx: GraphicsContext, size: CGSize) {
        guard let peak = timeline.peakSlot,
              let peakIndex = timeline.slots.firstIndex(where: { $0.time == peak.time })
        else { return }

        let slots       : [MilkywayPosition] = timeline.slots
        let leftPad     : CGFloat            = 12
        let rightPad    : CGFloat            = 12
        let topPad      : CGFloat            = 28
        let bottomPad   : CGFloat            = 36
        let chartWidth  : CGFloat            = size.width  - leftPad - rightPad
        let chartHeight : CGFloat            = size.height - topPad  - bottomPad

        let px : CGFloat = leftPad + CGFloat(peakIndex) / CGFloat(slots.count - 1) * chartWidth
        let py : CGFloat = topPad + chartHeight - ((max(-10, min(60, peak.coreAltitude)) + 10) / 70 * chartHeight)

        // Glow dot
        ctx.fill(
            Path(ellipseIn: CGRect(x: px - 5, y: py - 5, width: 10, height: 10)),
            with: .color(peak.quality.color.opacity(0.3))
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: px - 3, y: py - 3, width: 6, height: 6)),
            with: .color(peak.quality.color)
        )

        // Label
        ctx.draw(
            Text("\(Int(peak.coreAltitude))°")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(peak.quality.color),
            at: CGPoint(x: px, y: py - 14), anchor: .center
        )
        ctx.draw(
            Text(timeFormatter.string(from: peak.time))
                .font(.system(size: 7).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6)),
            at: CGPoint(x: px, y: py - 24), anchor: .center
        )
    }

    private func drawWindowLabels(ctx: GraphicsContext, size: CGSize) {
        let y : CGFloat = size.height - 14

        if let start : Date = timeline.windowStart {
            ctx.draw(
                Text("Core rises \(timeFormatter.string(from: start))")
                    .font(.system(size: 7).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5)),
                at: CGPoint(x: 16, y: y), anchor: .leading
            )
        }

        if let end : Date = timeline.windowEnd {
            ctx.draw(
                Text("Sets \(timeFormatter.string(from: end))")
                    .font(.system(size: 7).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5)),
                at: CGPoint(x: size.width - 16, y: y), anchor: .trailing
            )
        }

        // No window message
        if timeline.windowStart == nil {
            ctx.draw(
                Text("Milky Way core not visible tonight")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.4)),
                at: CGPoint(x: size.width / 2, y: size.height / 2), anchor: .center
            )
        }
    }

    private func drawHourLabels(ctx: GraphicsContext, size: CGSize) {
        guard !timeline.slots.isEmpty else { return }

        let slots      : [MilkywayPosition] = timeline.slots
        let leftPad    : CGFloat            = 12
        let rightPad   : CGFloat            = 12
        let chartWidth : CGFloat            = size.width - leftPad - rightPad
        let y          : CGFloat            = size.height - 24
        var calendar   : Calendar           = Calendar(identifier: .gregorian)
        calendar.timeZone = timeline.timeZone

        for (i, slot) in slots.enumerated() {
            let components : DateComponents = calendar.dateComponents([.hour, .minute], from: slot.time)
            let minute     : Int            = components.minute ?? 0
            let hour       : Int            = components.hour   ?? 0

            guard minute == 0 && hour % 3 == 0 else { continue }

            let x : CGFloat = leftPad + CGFloat(i) / CGFloat(slots.count - 1) * chartWidth

            ctx.draw(
                Text(String(format: "%02d", hour))
                    .font(.system(size: 7).monospacedDigit())
                    .foregroundStyle(.white.opacity(slot.isVisible ? 0.6 : 0.25)),
                at: CGPoint(x: x, y: y),
                anchor: .center
            )
        }
    }
    
    private func drawTitle(ctx: GraphicsContext, size: CGSize) {
        ctx.draw(
            Text("MILKY WAY CORE")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .kerning(1.2),
            at: CGPoint(x: size.width / 2, y: 14), anchor: .center
        )
    }
}
