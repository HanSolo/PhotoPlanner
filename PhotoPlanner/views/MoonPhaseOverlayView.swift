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
        self.phase                    = phase
        let formatter : DateFormatter = DateFormatter()
        formatter.timeStyle           = .short
        formatter.timeZone            = phase.timeZone
        self.timeFormatter            = formatter
    }
    

    var body: some View {
        GeometryReader { geometry in
            Canvas { ctx, size in
                drawMoonDisc(ctx: ctx, size: size)
                drawPhaseInfo(ctx: ctx, size: size)
                drawRiseSet(ctx: ctx, size: size)
                drawMilkyWayImpact(ctx: ctx, size: size)
            }
            .frame(width: geometry.size.width - 100, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
            .offset(x: 50, y: 100)
        }
    }


    private func drawMoonDisc(ctx: GraphicsContext, size: CGSize) {
        let centreX  : CGFloat = size.width * 0.18
        let centreY  : CGFloat = size.height * 0.45
        let radius   : CGFloat = min(size.width * 0.13, 28)
        
        // Clip to circle then draw the moon texture
        let discRect : CGRect = CGRect(x:centreX - radius, y: centreY - radius, width: radius * 2, height: radius * 2)

        ctx.drawLayer { ctx1 in
            // Clip to circular disc
            ctx1.clip(to: Path(ellipseIn: discRect))

            // Draw moon texture (rotated for observer latitude)
            if let moonImage : UIImage = UIImage(named: "moon") {
                var imageContext = ctx1
                imageContext.opacity = 1.0

                // Rotate based on observer latitude
                // Northern hemisphere : 0° rotation
                // Southern hemisphere : 180° rotation
                // Intermediate        : proportional
                let latitudeRotation : CGFloat = latitudeBasedRotation(phase.altitude)

                imageContext.drawLayer { rotatedContext in
                    // Translate to disc centre, rotate, translate back
                    rotatedContext.transform = CGAffineTransform.identity
                                                                .translatedBy(x: centreX, y: centreY)
                                                                .rotated(by: latitudeRotation)
                                                                .translatedBy(x: -centreX, y: -centreY)

                    rotatedContext.draw(Image(uiImage: moonImage), in: discRect)
                }
            }
        }

        // Dark mask over the unlit portion of the moon
        ctx.drawLayer { ctx1 in
            ctx1.clip(to: Path(ellipseIn: discRect))

            let shadowPath : Path = shadowOverlayPath(centre: CGPoint(x: centreX, y: centreY), radius: radius, phaseAngle: phase.phaseAngle, isWaxing: phase.isWaxing)

            // Unlit side (near black with slight transparency to show earthshine effect)
            ctx1.fill(shadowPath, with: .color(Color(white: 0.0, opacity: 0.82)))
        }
        
        ctx.stroke(Path(ellipseIn: discRect), with: .color(.white.opacity(0.25)), lineWidth: 0.5)                
    }

    
    // Returns the path covering the UNLIT portion of the moon
    private func shadowOverlayPath(centre: CGPoint, radius: CGFloat, phaseAngle: Double, isWaxing: Bool) -> Path {
        var path : Path = Path()

        // Full shadow (new moon)
        if phase.illumination < 0.02 {
            path.addEllipse(in: CGRect(
                x: centre.x - radius, y: centre.y - radius,
                width: radius * 2, height: radius * 2
            ))
            return path
        }

        // No shadow (full moon)
        if phase.illumination > 0.98 { return path }

        // Terminator x-scale:
        //  phaseAngle 0°   (new)     -> terminatorX =  1.0 (shadow fills disc)
        //  phaseAngle 90°  (quarter) -> terminatorX = 0.0 (straight terminator)
        //  phaseAngle 180° (full)    -> terminatorX = -1.0 (no shadow)
        let terminatorX : CGFloat = CGFloat(cos(phaseAngle * .pi / 180))

        // Waxing: lit on right, shadow on left
        // Waning: lit on left, shadow on right
        let flip        : CGFloat = isWaxing ? 1.0 : -1.0

        // Shadow covers the unlit half, starts from the terminator and sweeps around the dark side of the moon
        path.move(to: CGPoint(x: centre.x, y: centre.y - radius))

        // Arc around the dark side (180°)
        path.addArc(center: centre, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: isWaxing)

        // Terminator curve back to top (elliptical Bézier approximation)
        let controlOffset : CGFloat = terminatorX * radius * 1.35 * flip
        path.addCurve(to: CGPoint(x: centre.x, y: centre.y - radius), control1: CGPoint(x: centre.x + controlOffset, y: centre.y + radius), control2: CGPoint(x: centre.x + controlOffset, y: centre.y - radius))

        path.closeSubpath()
        return path
    }
            

    private func latitudeBasedRotation(_ moonAltitude: Double) -> CGFloat {
        // The moon's orientation as seen from Earth depends on
        // the observer's latitude and the moon's position in the sky.
        // At the equator the moon appears "upright",
        // in the northern hemisphere it tilts clockwise,
        // in the southern hemisphere it tilts counter-clockwise.
        //
        // We use the moon's altitude as a proxy — when low on the
        // horizon the tilt is more pronounced, when high overhead less so.
        // A full parallactic angle calculation would need azimuth and
        // latitude which aren't available here, so this is a reasonable
        // visual approximation.
        //
        // For a more precise implementation pass the observer's
        // latitude and the moon's azimuth to calculate the exact
        // parallactic angle.
        let altitudeFactor : CGFloat = CGFloat(max(0, min(90, moonAltitude)) / 90.0)
        return altitudeFactor * .pi * 0.25   // max ~45° tilt at zenith
    }

    
    private func drawPhaseInfo(ctx: GraphicsContext, size: CGSize) {
        let textCenterX : CGFloat = size.width * 0.58
        
        ctx.draw(Text("MOON").font(.system(size: 8, weight: .semibold)).foregroundStyle(.white.opacity(0.45)).kerning(1.5), at: CGPoint(x: textCenterX, y: 16), anchor: .center)
        ctx.draw(Text(phase.phaseName.rawValue).font(.system(size: 13, weight: .bold)).foregroundStyle(phase.phaseName.color), at: CGPoint(x: textCenterX, y: 36), anchor: .center)
        ctx.draw(Text(String(format: "%.0f%% illuminated", phase.illumination * 100)).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6)), at: CGPoint(x: textCenterX, y: 52), anchor: .center)
    }

    
    private func drawRiseSet(ctx: GraphicsContext, size: CGSize) {
        let offsetX  : CGFloat = size.width * 0.42
        let riseText : String = phase.riseTime.map { "↑ " + timeFormatter.string(from: $0) } ?? "-"
        let setText  : String = phase.setTime.map  { "↓ " + timeFormatter.string(from: $0) } ?? "-"
                
        ctx.draw(Text("\(riseText)   \(setText)").font(.system(size: 9).monospacedDigit()).foregroundStyle(.yellow.opacity(0.7)), at: CGPoint(x: offsetX, y: 72), anchor: .leading)
    }


    private func drawMilkyWayImpact(ctx: GraphicsContext, size: CGSize) {
        let factor    : CGFloat = phase.phaseName.lightPollutionFactor
        let barWidth  : CGFloat = size.width * 0.35
        let barHeight : CGFloat = 5
        let x         : CGFloat = size.width * 0.42
        let y         : CGFloat = size.height - 16

        ctx.draw(Text("Milky Way impact").font(.system(size: 7)).foregroundStyle(.white.opacity(0.35)), at: CGPoint(x: x, y: y - 8), anchor: .leading)

        // Track
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: barWidth, height: barHeight), cornerRadius: 3), with: .color(.white.opacity(0.1)))

        // Fill (red when high impact)
        let fillColor: Color = factor < 0.3 ? .green : factor < 0.6 ? .orange : .red
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: barWidth * factor, height: barHeight), cornerRadius: 3), with: .color(fillColor.opacity(0.8)))
    }
}
