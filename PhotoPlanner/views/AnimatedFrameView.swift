//
//  AnimatedFrameView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 18.08.26.
//

import Foundation
import SwiftUI
import MapKit
internal import Combine


struct AnimatedFrameView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let viewModel  : CloudMapViewModel
    let mode       : CloudMapMode
    let coordinate : CLLocationCoordinate2D
    
    private var frames       : [CloudMapFrame] { mode == .radar ? viewModel.radarFrames       : viewModel.satelliteFrames    }
    private var isLoading    : Bool            { mode == .radar ? viewModel.radarLoading      : viewModel.satelliteLoading   }
    private var isFailed     : Bool            { mode == .radar ? viewModel.radarFailed       : viewModel.satelliteFailed    }
    private var currentIndex : Int             { mode == .radar ? viewModel.radarCurrentIndex : viewModel.satelliteCurrentIndex }

    private var currentFrame : CloudMapFrame? {
        guard !frames.isEmpty, currentIndex < frames.count else { return nil }
        return frames[currentIndex]
    }

    var body: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading \(mode.rawValue.lowercased()) frames…")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
            }
        } else if isFailed || frames.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                Text("\(mode.rawValue) data unavailable")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.center)
            }
        } else {
            VStack(spacing: 10) {

                // Frame image with optional nowcast border
                if let frame = currentFrame {
                    Image(uiImage: frame.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(frame.isNowcast ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2))
                }

                // Pill player
                FramePlayerView(viewModel: viewModel, mode: mode)
                    .padding(.horizontal, 4)

                // Attribution + coordinates
                HStack(spacing: 6) {
                    Image(systemName: mode.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mode.attribution)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if mode == .satellite {
                        Text("· hourly")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(String(format: "%.6f°N  %.6f°E", coordinate.latitude, coordinate.longitude))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
            }
            .padding(.vertical, 8)
            // Long press on radar image to change color scheme
            .contextMenu {
                if mode == .radar {
                    ForEach(LibreWxrColorScheme.allCases) { scheme in
                        Button {
                            Properties.instance.libreWxrColorScheme = scheme.id
                            Task {
                                await viewModel.loadRadarFrames(coordinate: coordinate, scale: UITraitCollection.current.displayScale)
                            }
                        } label: {
                            Label(scheme.name, systemImage: (Properties.instance.libreWxrColorScheme ?? 8) == scheme.id ? "checkmark.circle.fill" : "circle")
                                .font(Constants.REGULAR_FONT_10)
                        }
                    }
                }
            }
        }
    }
}
