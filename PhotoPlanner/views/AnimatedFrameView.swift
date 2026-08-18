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
    let viewModel   : CloudMapViewModel
    let mode        : CloudMapMode
    let coordinate  : CLLocationCoordinate2D
    let colorScheme : ColorScheme

    // Timer fires every 0.6s to advance frames
    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    private var frames       : [CloudMapFrame] { mode == .radar ? viewModel.radarFrames       : viewModel.satelliteFrames       }
    private var currentIndex : Int             { mode == .radar ? viewModel.radarCurrentIndex : viewModel.satelliteCurrentIndex }
    private var isLoading    : Bool            { mode == .radar ? viewModel.radarLoading      : viewModel.satelliteLoading      }
    private var isFailed     : Bool            { mode == .radar ? viewModel.radarFailed       : viewModel.satelliteFailed       }
    private var isPlaying    : Bool            { mode == .radar ? viewModel.radarPlaying      : viewModel.satellitePlaying      }

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

                // Frame image
                if let frame = currentFrame {
                    Image(uiImage: frame.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    frame.isNowcast ? Color.blue.opacity(0.6) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .if(mode == .radar) { view in
                            view.contextMenu {
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

                // Scrubber
                ScrubberView(viewModel: viewModel, mode: mode)
                    .padding(.horizontal, 4)

                // Controls
                HStack(spacing: 24) {
                    Button {
                        setPlaying(false)
                        stepBack()
                    } label: {
                        Image(systemName: "backward.frame.fill")
                            .font(.title3)
                    }

                    Button {
                        togglePlaying()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 32)
                    }

                    Button {
                        setPlaying(false)
                        stepForward()
                    } label: {
                        Image(systemName: "forward.frame.fill")
                            .font(.title3)
                    }
                }
                .foregroundStyle(colorScheme == .dark ? .white : .black)

                // Time label
                if let frame = currentFrame {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(viewModel.frameTimeLabel(for: frame))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(frame.isNowcast ? .blue : .secondary)
                        Text("— \(mode.attribution.components(separatedBy: "—").last?.trimmingCharacters(in: .whitespaces) ?? "")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(String(format: "%.6f°N  %.6f°E", coordinate.latitude, coordinate.longitude))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
            }
            .onReceive(timer) { _ in
                guard isPlaying else { return }
                stepForward()
            }
        }
    }

    private func stepForward() {
        if mode == .radar { viewModel.advanceRadarFrame() }
        else              { viewModel.advanceSatelliteFrame() }
    }

    private func stepBack() {
        if mode == .radar {
            guard !viewModel.radarFrames.isEmpty else { return }
            viewModel.radarCurrentIndex = (viewModel.radarCurrentIndex - 1 + viewModel.radarFrames.count) % viewModel.radarFrames.count
        } else {
            guard !viewModel.satelliteFrames.isEmpty else { return }
            viewModel.satelliteCurrentIndex = (viewModel.satelliteCurrentIndex - 1 + viewModel.satelliteFrames.count) % viewModel.satelliteFrames.count
        }
    }

    private func togglePlaying() {
        if mode == .radar { viewModel.radarPlaying.toggle() }
        else              { viewModel.satellitePlaying.toggle() }
    }

    private func setPlaying(_ value: Bool) {
        if mode == .radar { viewModel.radarPlaying     = value }
        else              { viewModel.satellitePlaying = value }
    }
}
