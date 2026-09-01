//
//  RadarMapOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 31.08.26.
//
import Foundation
import SwiftUI
import MapKit



struct RadarMapOverlayView: View {

    let viewModel : RadarMapOverlayViewModel
    
    
    var body: some View {
        ZStack {
            if viewModel.isVisible {
                // Radar tile canvas
                if !viewModel.tiles.isEmpty {
                    Canvas { ctx, size in
                        if let region = viewModel.currentRegion {
                            for (tile, image) in viewModel.tiles {
                                let rect = Helper.tileRect(tile: tile, region: region, canvasSize: size)
                                guard let resolved = try? ctx.resolve(Image(uiImage: image)) else { continue }
                                var tileCtx     = ctx
                                tileCtx.opacity = 0.65
                                tileCtx.draw(resolved, in: rect)
                            }
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                // Loading / no-data hint
                if viewModel.isLoading {
                    VStack(alignment: .center) {
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
                        .padding(.bottom, 180)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.tooManyTiles {
                    VStack(alignment: .center) {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                                .font(.caption2)
                            Text("Zoom in to show radar overlay")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.bottom, 180)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.tiles.isEmpty {
                    // no data hint
                }
            }
        }
    }
}
