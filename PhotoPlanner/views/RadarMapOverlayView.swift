//
//  RadarMapOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 31.08.26.
//
import Foundation
import SwiftUI



struct RadarMapOverlayView: View {

    let viewModel : RadarMapOverlayViewModel

    var body: some View {
        ZStack {
            if viewModel.isVisible {
                // Radar tile canvas
                if !viewModel.tiles.isEmpty {
                    Canvas { ctx, size in
                        for (_, image, rect) in viewModel.tiles {
                            guard let resolved = try? ctx.resolve(Image(uiImage: image)) else { continue }
                            var tileCtx     = ctx
                            tileCtx.opacity = 0.65
                            tileCtx.draw(resolved, in: rect)
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                // Loading / no-data hint
                if viewModel.isLoading || viewModel.tiles.isEmpty {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                                Text("Loading radar…")
                                    .font(.caption2)
                            } else {
                                Image(systemName: "dot.radiowaves.up.forward")
                                    .font(.caption2)
                                Text("No radar data for current area")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                    }
                }
            }
        }
    }
}
