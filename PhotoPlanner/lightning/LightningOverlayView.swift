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
    let viewModel: LightningOverlayViewModel

    var body: some View {
        if viewModel.isVisible, let region = viewModel.visibleRegion {
            TimelineView(.animation) { context in
                Canvas { ctx, size in
                    let now = context.date
                    for strike in viewModel.strikes {
                        let age : Double = strike.age(at: now)
                        guard age < 300 else { continue }
                        let point : CGPoint = Helper.screenPoint(for: CLLocationCoordinate2D(latitude: strike.latitude, longitude: strike.longitude), in: region, size: size)
                        drawStrike(ctx: ctx, point: point, phase: strike.phase(at: now), age: age, color: strike.color(at: now), opacity: strike.opacity(at: now))
                    }
                }
                .onChange(of: context.date) { _, _ in
                    viewModel.pruneOldStrikes()
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func drawStrike(ctx: GraphicsContext, point: CGPoint, phase: LightningStrike.AnimationPhase, age: Double, color: Color, opacity: Double) {
        switch phase {

        case .expanding:
            let progress     = age / 0.03
            let flashOpacity = (1.0 - progress) * opacity
            let radius: CGFloat = 45

            ctx.withCGContext { cgCtx in
                cgCtx.saveGState()
                cgCtx.setAlpha(flashOpacity)
                                
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: Constants.STRIKE_COLORS, locations: Constants.STRIKE_GRADIENT_STOPS) else {
                    cgCtx.restoreGState()
                    return
                }

                cgCtx.drawRadialGradient(gradient, startCenter: CGPoint(x: point.x, y: point.y), startRadius: 0, endCenter: CGPoint(x: point.x, y: point.y), endRadius: radius, options: .drawsAfterEndLocation)
                cgCtx.restoreGState()
            }

        case .contracting:
            let progress  : CGFloat         = (age - 0.03) / 0.19
            let dotRadius : CGFloat         = max(2, 10 * CGFloat(1 - progress) + 2)
            var dotCtx    : GraphicsContext = ctx
            dotCtx.opacity = (1.0 - progress * 0.5) * opacity
            dotCtx.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(color))

        case .persistent:
            let dotRadius : CGFloat         = 3
            var glowCtx   : GraphicsContext = ctx
            glowCtx.opacity = opacity * 0.25
            glowCtx.fill(Path(ellipseIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)), with: .color(color))
            var dotCtx    : GraphicsContext = ctx
            dotCtx.opacity = opacity
            dotCtx.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(color))
        }
    }
}
