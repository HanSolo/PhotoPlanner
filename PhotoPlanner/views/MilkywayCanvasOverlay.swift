//
//  MilkywayCanvasOverlay.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 16.06.26.
//


import Foundation
import SwiftUI
import CoreLocation


struct MilkywayCanvasOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let viewModel : MilkywayMapViewModel
    let onClose   :   () -> Void

    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let foregroundColor : Color = colorScheme == .dark ? .white : .black
                
                Canvas { ctx, size in
                    let _ = viewModel.selectedTime
                    let center     : CGPoint       = CGPoint(x: size.width / 2, y: size.height / 2)
                    let maxRadius  : CGFloat       = min(size.width, size.height) * 0.45
                    let projection : SkyProjection = SkyProjection(maxRadius: maxRadius, center: center)

                    let backgroundOpacity: CGFloat = colorScheme == .dark ? 0.15 : 0.35
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - maxRadius, y: center.y - maxRadius, width: maxRadius * 2, height: maxRadius * 2)), with: .color(Color.black.opacity(backgroundOpacity)))
                    
                    drawHorizonRing(ctx: ctx, projection: projection)
                    drawCardinalMarkers(ctx: ctx, projection: projection)
                    drawGalacticBand(ctx: ctx, size: size, projection: projection)
                    drawCurrentPosition(ctx: ctx, size: size, projection: projection)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                if viewModel.isCalculating {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(foregroundColor)
                        Text("Calculating positions…")
                            .font(.caption2)
                            .foregroundStyle(foregroundColor.opacity(0.7))
                    }
                    .padding(12)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if !viewModel.isCalculating {
                    VStack {
                        infoCard
                            .padding(.top, 100)
                            .frame(width: geometry.size.width - 120)
                        Spacer()
                    }
                }
                
                VStack {
                    Spacer()
                    MilkywayTimeSliderView(selectedTime: Binding(get: { viewModel.selectedTime }, set: { viewModel.selectedTime = $0 }), viewModel: viewModel)
                        .padding(.bottom, 110)
                        .frame(width: geometry.size.width - 120)
                }
            }
        }
    }

    
    private var infoCard: some View {
        let position = viewModel.currentGalacticCenterPosition
        let quality  : MilkywayPosition.Quality = position?.quality ?? .notVisible
        
        return VStack {
            HStack(spacing: 12) {
                Circle()
                    .fill(calcQualityColor(quality))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MILKY WAY CORE")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .kerning(1.2)
                    Text(quality == .notVisible ? "Not visible" : quality.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(calcQualityColor(quality))
                }
                
                Spacer()

                if let pos = position, pos.quality != MilkywayPosition.Quality.notVisible {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f° alt", pos.altitude))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                        Text(String(format: "%.1f° az", pos.azimuth))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else if !viewModel.darknessWindow.hasDarkness {
                    Text("No astronomical darkness tonight")
                        .font(.caption2).foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func drawHorizonRing(ctx: GraphicsContext, projection: SkyProjection) {
        // Outer horizon
        ctx.stroke(Path(ellipseIn: CGRect(x: projection.center.x - projection.maxRadius, y: projection.center.y - projection.maxRadius, width: projection.maxRadius * 2, height: projection.maxRadius * 2)), with: .color(.white.opacity(0.15)), lineWidth: 1)
        // 30° and 60° altitude rings
        for altDeg in [30.0, 60.0] {
            let r = CGFloat(1.0 - altDeg / 90.0) * projection.maxRadius
            ctx.stroke(Path(ellipseIn: CGRect(x: projection.center.x - r, y: projection.center.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.06)), lineWidth: 0.5)
        }
    }

    private func drawCardinalMarkers(ctx: GraphicsContext, projection: SkyProjection) {
        for (label, azimuth) in [("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)] {
            let angleRad    : CGFloat = CGFloat((azimuth - 90.0) * .pi / 180.0)
            let horizonPt   : CGPoint = projection.calcHorizonPoint(azimuth: azimuth)
            let tickInnerPt : CGPoint = CGPoint(x: projection.center.x + (projection.maxRadius - 6) * cos(angleRad), y: projection.center.y + (projection.maxRadius - 6) * sin(angleRad))
            let labelPt     : CGPoint = CGPoint(x: projection.center.x + (projection.maxRadius + 16) * cos(angleRad), y: projection.center.y + (projection.maxRadius + 16) * sin(angleRad))

            var tick : Path = Path()
            tick.move(to: tickInnerPt)
            tick.addLine(to: horizonPt)
            ctx.stroke(tick, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

            ctx.draw(Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.5)), at: labelPt, anchor: .center)
        }
    }

    private func drawGalacticBand(ctx: GraphicsContext, size: CGSize, projection: SkyProjection) {
        let isDark : Bool = viewModel.isCurrentlyDark

        // Sample the galactic plane at current time
        let planePoints : [(Double, Double)] = viewModel.currentGalacticPlanePoints()
        guard !planePoints.isEmpty else { return }

        // Draw outer band edges (b = ±10°) as filled area
        // then core spine (b = 0°) as bright line
        // Use multiple latitude samples to create band width effect

        // Band fill (b = -10° to +10°)
        // Build upper and lower edge paths for fill
        guard let coord = viewModel.coordinate else { return }

        let bandLatitudes: [Double] = [-10, -7, -4, -2, 0, 2, 4, 7, 10]
        
        for b in bandLatitudes {            
            let bandPoints = GalacticConverter.galacticPlanePoints(at: coord, time: viewModel.selectedTime, stepDegrees: 2.0).enumerated().map { i, _ -> (altitude: Double, azimuth: Double) in
                let l         : Double           = Double(i) * 2.0
                let (ra, dec) : (Double, Double) = GalacticConverter.galacticToEquatorial(l: l, b: b)
                return GalacticConverter.equatorialToHorizontal(ra: ra, dec: dec, coordinate: coord, time: viewModel.selectedTime)
            }

            // Opacity varies by latitude, brighter at core (b=0), dimmer at edges
            let distFromCore : Double = abs(b)
            let opacity      : Double = isDark ? max(0.05, 0.7 - distFromCore * 0.06) : max(0.02, 0.2 - distFromCore * 0.02)

            // Line width varies by latitude
            let lineWidth : CGFloat = b == 0 ? 3.0 : (distFromCore < 5 ? 1.8 : 1.2)

            // Colour — core is warm white/yellow, edges cooler
            let bandColor : Color = b == 0 ? Color(red: 0.95, green: 0.92, blue: 0.80) : Color(red: 0.70, green: 0.65, blue: 0.90)

            drawGalacticLine(ctx: ctx, size: size, projection: projection, points: bandPoints, color: bandColor.opacity(opacity), lineWidth: lineWidth)
        }

        // Galactic center indicator
        let (gcAlt, gcAz) = GalacticConverter.equatorialToHorizontal(ra: GalacticConverter.galacticCenterRA, dec: GalacticConverter.galacticCenterDec, coordinate: coord, time: viewModel.selectedTime)
        
        if gcAlt > 0, let gcPoint = projection.calcScreenPoint(altitude: gcAlt, azimuth: gcAz) {
            let gcColor : Color = isDark ? Color(red: 1.0, green: 0.8, blue: 0.4) : Color(red: 1.0, green: 0.8, blue: 0.4).opacity(0.4)

            // Glow
            ctx.fill(Path(ellipseIn: CGRect(x: gcPoint.x - 12, y: gcPoint.y - 12, width: 24, height: 24)), with: .color(gcColor.opacity(0.2)))
            
            // Main dot
            ctx.fill(Path(ellipseIn: CGRect(x: gcPoint.x - 6, y: gcPoint.y - 6, width: 12, height: 12)), with: .color(gcColor))
            
            // White center
            ctx.fill(Path(ellipseIn: CGRect(x: gcPoint.x - 2.5, y: gcPoint.y - 2.5, width: 5, height: 5)), with: .color(.white.opacity(0.9)))
        }
    }

    private func drawGalacticLine(ctx: GraphicsContext, size: CGSize, projection: SkyProjection, points: [(altitude: Double, azimuth: Double)], color: Color, lineWidth: CGFloat) {
        var currentPath     : Path   = Path()
        var pathHasPoints   : Bool   = false
        var previousAzimuth : Double = points.first?.azimuth ?? 0

        for point in points {
            guard let screenPt = projection.calcScreenPoint(altitude: point.altitude, azimuth: point.azimuth) else {
                // Below horizon — stroke current path and start new one
                if pathHasPoints {
                    ctx.stroke(currentPath, with: .color(color), lineWidth: lineWidth)
                    currentPath   = Path()
                    pathHasPoints = false
                }
                previousAzimuth = point.azimuth
                continue
            }

            // Detect azimuth wraparound (0°/360° boundary)
            // Large azimuth jump means we've wrapped around — break the path
            var azimuthDelta : Double = abs(point.azimuth - previousAzimuth)
            if azimuthDelta > 180 { azimuthDelta = 360 - azimuthDelta }

            if azimuthDelta > 90 && pathHasPoints {
                ctx.stroke(currentPath, with: .color(color), lineWidth: lineWidth)
                currentPath   = Path()
                pathHasPoints = false
            }

            if !pathHasPoints {
                currentPath.move(to: screenPt)
            } else {
                currentPath.addLine(to: screenPt)
            }

            pathHasPoints   = true
            previousAzimuth = point.azimuth
        }

        if pathHasPoints {
            ctx.stroke(currentPath, with: .color(color), lineWidth: lineWidth)
        }
    }
    
    private func drawCurrentPosition(ctx: GraphicsContext, size: CGSize, projection: SkyProjection) {
        guard let position = viewModel.currentGalacticCenterPosition else { return }

        let isVisible    : Bool    = position.quality != MilkywayPosition.Quality.notVisible
        let coreColor    : Color   = isVisible ? calcQualityColor(position.quality) : Color.white.opacity(0.2)
        let horizonPoint : CGPoint = projection.calcHorizonPoint(azimuth: position.azimuth)

        // Dashed direction line from center to horizon, always shown
        var linePath : Path = Path()
        linePath.move(to: projection.center)
        linePath.addLine(to: horizonPoint)
        ctx.stroke(linePath, with: .color(coreColor.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // Sample galactic latitudes on both sides of the core
        // to show the full band width at the selected time
        guard let coord : CLLocationCoordinate2D = viewModel.coordinate else { return }

        // The galactic longitude of the core at the current azimuth,
        // we sample b = ±5, ±10, ±15, ±20 at the same longitude (l=0)
        // since we want dots along the band through the core
        let bandLatitudes : [(l: Double, sizeFraction: Double, opacityFraction: Double)] = [
            (-80, 0.20, 0.20),
            (-50, 0.35, 0.35),
            (-25, 0.55, 0.55),
            (-10, 0.75, 0.75),
            (  0, 1.00, 1.00),   // core
            ( 10, 0.75, 0.75),
            ( 25, 0.55, 0.55),
            ( 50, 0.35, 0.35),
            ( 80, 0.20, 0.20)
        ]

        // Find the galactic longitude that corresponds to the current
        // core azimuth by using l=0 (galactic center direction)
        // The band dots are spaced along galactic latitude at l=0
        for band in bandLatitudes {
            let (ra, dec)   : (Double, Double) = GalacticConverter.galacticToEquatorial(l: band.l, b: 0)
            let (alt, az)   : (Double, Double) = GalacticConverter.equatorialToHorizontal(ra: ra, dec: dec, coordinate: coord, time: viewModel.selectedTime)

            guard let point : CGPoint          = projection.calcScreenPoint(altitude: alt, azimuth: az) else { continue }

            let dotRadius   : CGFloat          = CGFloat(8.0 * band.sizeFraction)
            let opacity     : Double           = band.opacityFraction
            let dotColor    : Color            = isVisible ? calcQualityColor(position.quality).opacity(opacity) : Color.white.opacity(opacity * 0.2)

            // Glow for larger dots
            if band.sizeFraction >= 0.5 {
                ctx.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius * 2, y: point.y - dotRadius * 2, width: dotRadius * 4, height: dotRadius * 4)), with: .color(dotColor.opacity(0.15)))
            }

            // Main dot
            ctx.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(dotColor))

            // White center only on the core dot
            if band.l == 0 {
                ctx.fill(Path(ellipseIn: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)), with: .color(.white.opacity(0.9)))

                // Altitude label with dark pill background
                let labelText  : String  = String(format: "%.0f°", alt)
                let angleRad   : CGFloat = CGFloat((az - 90.0) * .pi / 180.0)
                let labelPoint : CGPoint = CGPoint(x: point.x + 22 * cos(angleRad), y: point.y + 22 * sin(angleRad))

                let pillWidth  : CGFloat = 32
                let pillHeight : CGFloat = 16
                ctx.fill(Path(roundedRect: CGRect(x: labelPoint.x - pillWidth  / 2, y: labelPoint.y - pillHeight / 2, width: pillWidth, height: pillHeight), cornerRadius: pillHeight / 2), with: .color(Color.black.opacity(0.65)))
                ctx.draw(Text(labelText).font(.system(size: 10, weight: .bold).monospacedDigit()).foregroundStyle(coreColor), at: labelPoint, anchor: .center)
            }
        }

        // Below horizon fallback — small indicator on horizon ring
        if projection.calcScreenPoint(altitude: position.altitude, azimuth: position.azimuth) == nil {
            ctx.fill(Path(ellipseIn: CGRect(x: horizonPoint.x - 5, y: horizonPoint.y - 5, width: 10, height: 10)), with: .color(.white.opacity(0.2)))
        }
    }
    
    private func calcQualityColor(_ quality: MilkywayPosition.Quality) -> Color {
        switch quality {
            case .notVisible : return .white.opacity(0.5)
            case .poor       : return Color(red: 0.3, green: 0.1, blue: 0.5).opacity(0.7)
            case .fair       : return Color(red: 0.5, green: 0.2, blue: 0.8)
            case .good       : return Color(red: 0.7, green: 0.4, blue: 1.0)
            case .excellent  : return Color(red: 0.9, green: 0.8, blue: 1.0)
        }
    }

    private func calcDotSize(for position: MilkywayMapPosition) -> CGFloat {
        if !position.isAstronomicallyDark || position.altitude <= 0 { return 2.5 }
        switch position.quality {
            case .notVisible : return 2.5
            case .poor       : return 3.0
            case .fair       : return 3.5
            case .good       : return 4.0
            case .excellent  : return 4.5
        }
    }
}
