//
//  FramePlayerView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 19.08.26.
//

import Foundation
import SwiftUI
internal import Combine


struct FramePlayerView: View {

    let viewModel  : CloudMapViewModel
    let mode       : CloudMapMode
    @Environment(\.colorScheme) private var colorScheme

    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    private var frames       : [CloudMapFrame] { mode == .radar ? viewModel.radarFrames       : viewModel.satelliteFrames       }
    private var currentIndex : Int             { mode == .radar ? viewModel.radarCurrentIndex : viewModel.satelliteCurrentIndex }
    private var isPlaying    : Bool            { mode == .radar ? viewModel.radarPlaying      : viewModel.satellitePlaying      }
    private var frameCount   : Int             { frames.count }

    private var nowcastStartIndex: Int? {
        frames.lastIndex(where: { !$0.isNowcast }).map { $0 + 1 }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.black.opacity(0.65))

            HStack(spacing: 12) {

                // Play / pause
                Button {
                    togglePlaying()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 40, height: 40)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)

                // Time label
                Text(currentTimeLabel)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 44, alignment: .leading)

                // Track + thumb
                GeometryReader { geo in
                    ZStack(alignment: .leading) {

                        // Background track
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .frame(height: 4)

                        // Past frames track
                        if frameCount > 1 {
                            let pastWidth: CGFloat = {
                                guard let ns = nowcastStartIndex, ns > 0 else { return geo.size.width }
                                return geo.size.width * CGFloat(ns) / CGFloat(frameCount)
                            }()
                            Capsule()
                                .fill(.white.opacity(0.6))
                                .frame(width: pastWidth, height: 4)

                            // Nowcast track
                            if let ns = nowcastStartIndex, ns < frameCount {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.7))
                                    .frame(width: geo.size.width - pastWidth, height: 4)
                                    .offset(x: pastWidth)
                            }
                        }

                        // Thumb
                        let thumbX: CGFloat = frameCount > 1
                            ? geo.size.width * CGFloat(currentIndex) / CGFloat(frameCount - 1)
                            : 0
                        Circle()
                            .fill(.white)
                            .frame(width: 18, height: 18)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: thumbX - 9)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        setPlaying(false)
                                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                                        setIndex(Int((fraction * Double(frameCount - 1)).rounded()))
                                    }
                            )
                    }
                }
                .frame(height: 18)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(height: 60)
        .onReceive(timer) { _ in
            guard isPlaying, !frames.isEmpty else { return }
            stepForward()
        }
    }

    private var currentTimeLabel: String {
        let frames = mode == .radar ? viewModel.radarFrames : viewModel.satelliteFrames
        let index  = mode == .radar ? viewModel.radarCurrentIndex : viewModel.satelliteCurrentIndex
        guard !frames.isEmpty, index < frames.count else { return "--:--" }
        return viewModel.frameTimeLabel(for: frames[index])
    }

    private func stepForward() {
        mode == .radar ? viewModel.advanceRadarFrame() : viewModel.advanceSatelliteFrame()
    }

    private func togglePlaying() {
        if mode == .radar { viewModel.radarPlaying.toggle() }
        else              { viewModel.satellitePlaying.toggle() }
    }

    private func setPlaying(_ value: Bool) {
        if mode == .radar { viewModel.radarPlaying     = value }
        else              { viewModel.satellitePlaying = value }
    }

    private func setIndex(_ index: Int) {
        guard index >= 0 && index < frameCount else { return }
        if mode == .radar { viewModel.radarCurrentIndex     = index }
        else              { viewModel.satelliteCurrentIndex = index }
    }
}
