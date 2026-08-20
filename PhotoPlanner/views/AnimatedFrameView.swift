//
//  AnimatedFrameView.swift
//  PhotoPlanner
//

import Foundation
import SwiftUI
import CoreLocation
internal import Combine


struct AnimatedFrameView: View {

    let viewModel  : CloudMapViewModel
    let mode       : CloudMapMode
    let coordinate : CLLocationCoordinate2D
    @Environment(\.colorScheme) private var colorScheme

    private var isLoading : Bool            { mode == .radar ? viewModel.radarLoading : viewModel.satelliteLoading }
    private var isFailed  : Bool            { mode == .radar ? viewModel.radarFailed  : viewModel.satelliteFailed  }
    private var frames    : [CloudMapFrame] { mode == .radar ? viewModel.radarFrames  : viewModel.satelliteFrames  }

    
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

                // Frame image — uses currentImage() which composites wind arrows if enabled
                if let image = viewModel.currentImage(for: mode) {
                    let currentFrame = mode == .radar
                        ? viewModel.radarFrames[safe: viewModel.radarCurrentIndex]
                        : viewModel.satelliteFrames[safe: viewModel.satelliteCurrentIndex]

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    currentFrame?.isNowcast == true ? Color.accentColor.opacity(0.6) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .contextMenu {
                            if mode == .radar {
                                ForEach(LibreWxrColorScheme.allCases) { scheme in
                                    Button {
                                        Properties.instance.libreWxrColorScheme = scheme.id
                                        Task {
                                            await viewModel.loadRadarFrames(
                                                coordinate: coordinate,
                                                scale:      UITraitCollection.current.displayScale
                                            )
                                        }
                                    } label: {
                                        Label(
                                            scheme.name,
                                            systemImage: (Properties.instance.libreWxrColorScheme ?? 8) == scheme.id
                                                ? "checkmark.circle.fill"
                                                : "circle"
                                        )
                                    }
                                }
                            }
                        }
                }

                // Pill player
                FramePlayerView(viewModel: viewModel, mode: mode)
                    .padding(.horizontal, 4)

                // Attribution
                HStack(spacing: 6) {
                    Image(systemName: mode.icon)
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(mode.attribution)
                        .font(.caption2).foregroundStyle(.secondary)
                    if mode == .satellite {
                        Text("· hourly")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Text(String(format: "%.6f°N  %.6f°E", coordinate.latitude, coordinate.longitude))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
            }
            .padding(.vertical, 8)
        }
    }
}


private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
