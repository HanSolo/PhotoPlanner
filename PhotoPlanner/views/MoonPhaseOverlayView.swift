//
//  MoonPhaseOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.05.26.
//

import Foundation
import SwiftUI


struct MoonPhaseOverlayView: View {
    private let phase         : MoonPhase
    private let timeFormatter : DateFormatter
    
    init(phase: MoonPhase) {
        self.phase         = phase
        let f              = DateFormatter()
        f.timeStyle        = .short
        f.timeZone         = phase.timeZone
        self.timeFormatter = f
    }
    

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                //drawBackground(ctx: context, size: size)
                drawMoonDisc(ctx: context, size: size)
                drawPhaseInfo(ctx: context, size: size)
                drawRiseSet(ctx: context, size: size)
                drawMilkyWayImpact(ctx: context, size: size)
            }
            .background(.black.opacity(0.72))
            .frame(width: geometry.size.width - 100, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
            .offset(x: 50, y: 100)
        }
    }

    
    private func drawBackground(ctx: GraphicsContext, size: CGSize) {
        ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14), with: .color(Color(red: 0.03, green: 0.03, blue: 0.12)))
    }

    private func drawMoonDisc(ctx: GraphicsContext, size: CGSize) {
        let cx : CGFloat = 38
        let cy : CGFloat = 50
        let r  : CGFloat = 28

        // Dark disc base
        ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),with: .color(.white.opacity(0.1)))

        // Illuminated portion — simplified crescent/gibbous shape
        let illuminatedPath = illuminationPath(center: CGPoint(x: cx, y: cy), radius: r, illumination: phase.illumination, isWaxing: phase.isWaxing)
        ctx.fill(illuminatedPath, with: .color(phase.phaseName.color.opacity(0.85)))

        // Outer ring
        ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.2)), lineWidth: 1)        
    }

    
    private func illuminationPath(center: CGPoint, radius: CGFloat, illumination: Double, isWaxing: Bool) -> Path {
        var path = Path()

        // Full circle for full/new moon
        if illumination > 0.97 {
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            return path
        }
        if illumination < 0.03 { return path }

        // For crescent/gibbous: use elliptical terminator approximation
        // x-scale of terminator ellipse: 1.0 = full, 0.0 = quarter, -1.0 = new
        let terminatorX : CGFloat = CGFloat(cos(phase.phaseAngle * .pi / 180))
        let flip        : CGFloat = isWaxing ? 1 : -1

        path.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle:   .degrees(90), clockwise:  false)

        // Terminator as vertical ellipse
        let cp1 = CGPoint(x: center.x + flip * terminatorX * radius * 1.33, y: center.y - radius)
        let cp2 = CGPoint(x: center.x + flip * terminatorX * radius * 1.33, y: center.y + radius)

        path.addCurve(to: CGPoint(x: center.x, y: center.y - radius), control1: cp2, control2: cp1)
        path.closeSubpath()
        return path
    }

    
    private func drawPhaseInfo(ctx: GraphicsContext, size: CGSize) {
        ctx.draw(Text("MOON").font(.system(size: 8, weight: .semibold)).foregroundStyle(.white.opacity(0.45)).kerning(1.5), at: CGPoint(x: 138, y: 16), anchor: .center)
        ctx.draw(Text(phase.phaseName.rawValue).font(.system(size: 13, weight: .bold)).foregroundStyle(phase.phaseName.color), at: CGPoint(x: 138, y: 36), anchor: .center)
        ctx.draw(Text(String(format: "%.0f%% illuminated", phase.illumination * 100)).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6)), at: CGPoint(x: 138, y: 52), anchor: .center)
    }

    
    private func drawRiseSet(ctx: GraphicsContext, size: CGSize) {
        let riseText : String = phase.riseTime.map { "↑ " + timeFormatter.string(from: $0) } ?? "—"
        let setText  : String = phase.setTime.map  { "↓ " + timeFormatter.string(from: $0) } ?? "—"
                
        ctx.draw(Text("\(riseText)   \(setText)").font(.system(size: 9).monospacedDigit()).foregroundStyle(.yellow.opacity(0.7)), at: CGPoint(x: 108, y: 72), anchor: .leading)
    }


    private func drawMilkyWayImpact(ctx: GraphicsContext, size: CGSize) {
        let factor    : CGFloat = phase.phaseName.lightPollutionFactor
        let barWidth  : CGFloat = 80
        let barHeight : CGFloat = 5
        let x         : CGFloat = 108
        let y         : CGFloat = size.height - 16

        ctx.draw(Text("Milky Way impact").font(.system(size: 7)).foregroundStyle(.white.opacity(0.35)), at: CGPoint(x: x, y: y - 8), anchor: .leading)

        // Track
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight), cornerRadius: 3), with: .color(.white.opacity(0.1)))

        // Fill — red when high impact
        let fillColor: Color = factor < 0.3 ? .green : factor < 0.6 ? .orange : .red
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: barWidth * factor, height: barHeight), cornerRadius: 3), with: .color(fillColor.opacity(0.8)))
    }
}
