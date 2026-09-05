//
//  LightningOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.08.26.
//


import Foundation
import SwiftUI
import MapKit
import UIKit

struct LightningOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    let viewModel : LightningOverlayViewModel

    // Cached storm-cell screen positions — recomputed only when the visible
    // region, the cell data, or the view size changes, never inside the
    // per-frame animation callback. Doing that recomputation (or any other
    // @State mutation) inside onChange(of: context.date) on a .animation
    // TimelineView fires up to ~120x/sec and was the actual source of both
    // the flicker and the "tried to update multiple times per frame"
    // warnings — SwiftUI detects the tight mutate/redraw loop and complains.
    @State private var cachedCellPoints : [(cell: Cell, point: CGPoint)] = []

    var body: some View {
        GeometryReader { geo in
            // Lightning strikes need a per-frame clock to animate the flash.
            // Everything else (pruning, region/cell diffing) is intentionally
            // kept OUT of this timeline's onChange — see comments below.
            TimelineView(.animation) { context in
                Canvas { ctx, size in
                    guard viewModel.isVisible, let region = viewModel.visibleRegion else { return }
                    let now : Date = context.date
                    for strike in viewModel.strikes {
                        let age : Double = strike.age(at: now)
                        guard age < self.viewModel.maxAge else { continue }
                        let point : CGPoint = Helper.screenPoint(for: CLLocationCoordinate2D(latitude: strike.latitude, longitude: strike.longitude), in: region, size: size)
                        drawStrike(ctx: ctx, point: point, phase: strike.phase(at: now), age: age, color: strike.color(at: now, colorScheme: self.colorScheme), opacity: strike.opacity(at: now))
                    }

                    if viewModel.stormCellsVisible {
                        for (cell, point) in cachedCellPoints {
                            drawStormCell(cell: cell, at: point, ctx: &ctx)
                        }
                    }
                }
                // No state mutation here — purely reads viewModel.strikes to draw.
            }
            // Pruning only needs ~1s granularity given a 300s maxAge. Driving it
            // from a slow periodic timeline instead of the animation timeline
            // removes ~120x/sec of unnecessary @Observable mutation.
            .overlay {
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    Color.clear
                        .onChange(of: context.date) { _, _ in viewModel.pruneOldStrikes() }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                recomputeCellPoints(size: geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                recomputeCellPoints(size: newSize)
            }
            .onChange(of: viewModel.regionVersion) { _, _ in
                recomputeCellPoints(size: geo.size)
            }
            .onChange(of: viewModel.stormCells) { _, _ in
                recomputeCellPoints(size: geo.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func recomputeCellPoints(size: CGSize) {
        guard let region = viewModel.visibleRegion else {
            cachedCellPoints = []
            return
        }
        cachedCellPoints = viewModel.stormCells.map { cell in
            (cell, Helper.screenPoint(latitude: cell.lat ?? 0, longitude: cell.lon ?? 0, in: region, size: size))
        }
    }

    private func drawStrike(ctx: GraphicsContext, point: CGPoint, phase: LightningStrike.AnimationPhase, age: Double, color: Color, opacity: Double) {
        switch phase {
            case .flash:
                let progress     : CGFloat = age / 0.75 // 0.75s total
                let maxRadius    : CGFloat = 75
                let minRadius    : CGFloat = 3
                let radius       : CGFloat = maxRadius * CGFloat(1.0 - progress) + minRadius
                let flashOpacity : CGFloat = pow(1.0 - progress, 1.5) * opacity

                ctx.withCGContext { cgCtx in
                    cgCtx.saveGState()
                    cgCtx.setAlpha(flashOpacity)
                    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: Constants.STRIKE_COLORS, locations: Constants.STRIKE_GRADIENT_STOPS) else { cgCtx.restoreGState(); return }
                    cgCtx.drawRadialGradient(gradient, startCenter: CGPoint(x: point.x, y: point.y), startRadius: 0, endCenter: CGPoint(x: point.x, y: point.y), endRadius: radius, options: .drawsAfterEndLocation)
                    cgCtx.restoreGState()
                }

            case .persistent:
                let dotRadius : CGFloat         = 3
                var dotCtx    : GraphicsContext = ctx
                dotCtx.opacity = opacity
                dotCtx.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(color))
        }
    }

    private func drawStormCell(cell: Cell, at point: CGPoint, ctx: inout GraphicsContext) {
        let severity : Color   = severityColor(dbz: cell.maxDbz ?? 0)
        let radius   : CGFloat = symbolRadius(areaKm2: cell.areaKm2 ?? 0)

        // Storm cell marker
        let circleRect : CGRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        let circlePath : Path   = Path(ellipseIn: circleRect)
        ctx.fill(circlePath, with: .color(severity.opacity(0.75)))
        ctx.stroke(circlePath, with: .color(severity), lineWidth: 2)

        // Motion vector arrow
        drawCellMotionArrow(from: point, headingDeg: cell.motionHeadingDeg ?? 0, speedKmh: cell.motionSpeedKmh ?? 0, color: severity, ctx: &ctx)
    }

    private func drawCellMotionArrow(from origin: CGPoint, headingDeg: Double, speedKmh: Double, color: Color, ctx: inout GraphicsContext) {
        // Meteorological convention: 0 = N, 90 = E, clockwise.
        // Convert to standard math angle (0 = +x axis, counterclockwise) for CGPoint math.
        let headingRad : CGFloat = headingDeg * .pi / 180
        // screen y grows downward, so we build dx/dy directly from compass heading:
        let dx : CGFloat = sin(headingRad)
        let dy : CGFloat = -cos(headingRad)

        let length   : CGFloat = min(60, 15 + speedKmh * 0.6) // scale arrow length with speed, capped
        let endPoint : CGPoint = CGPoint(x: origin.x + dx * length, y: origin.y + dy * length)

        var linePath = Path()
        linePath.move(to: origin)
        linePath.addLine(to: endPoint)
        ctx.stroke(linePath, with: .color(color), lineWidth: 2.5)

        // Arrowhead
        let arrowLength : CGFloat = 8
        let arrowAngle  : CGFloat = .pi / 7
        let backAngle   : CGFloat = atan2(dy, dx) + .pi

        let p1 : CGPoint = CGPoint(x: endPoint.x + arrowLength * cos(backAngle + arrowAngle), y: endPoint.y + arrowLength * sin(backAngle + arrowAngle))
        let p2 : CGPoint = CGPoint(x: endPoint.x + arrowLength * cos(backAngle - arrowAngle), y: endPoint.y + arrowLength * sin(backAngle - arrowAngle))

        var arrowPath = Path()
        arrowPath.move(to: endPoint)
        arrowPath.addLine(to: p1)
        arrowPath.move(to: endPoint)
        arrowPath.addLine(to: p2)
        ctx.stroke(arrowPath, with: .color(color), lineWidth: 2.5)
    }

    private func severityColor(dbz: Double) -> Color {
        let key : Double = Constants.DBZ_COLORS.keys.filter { dbz > $0 }.first ?? 0
        return Constants.DBZ_COLORS[key]!
    }

    private func symbolRadius(areaKm2: Double) -> CGFloat {
        // sqrt scaling so radius tracks area, not diameter, roughly linearly on screen
        max(8, min(30, CGFloat(sqrt(areaKm2))))
    }
}
