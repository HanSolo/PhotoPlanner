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
    
    let viewModel: LightningOverlayViewModel

    var body: some View {
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
            }
            .onChange(of: context.date) { _, _ in
                viewModel.pruneOldStrikes()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
}
