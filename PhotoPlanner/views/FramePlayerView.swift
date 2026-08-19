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
    @Environment(\.colorScheme) private var colorScheme
    let viewModel  : CloudMapViewModel
    let mode       : CloudMapMode
    

    // Timer drives auto-play
    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    private var frames       : [CloudMapFrame] { mode == .radar ? viewModel.radarFrames       : viewModel.satelliteFrames       }
    private var currentIndex : Int             { mode == .radar ? viewModel.radarCurrentIndex : viewModel.satelliteCurrentIndex }
    private var isPlaying    : Bool            { mode == .radar ? viewModel.radarPlaying      : viewModel.satellitePlaying      }

    // Slider value — Double for smooth dragging
    @State private var sliderValue : Double = 0

    private var frameCount : Int { frames.count }

    private var currentFrame : CloudMapFrame? {
        guard !frames.isEmpty, currentIndex < frames.count else { return nil }
        return frames[currentIndex]
    }

    private var timeLabel : String {
        guard let frame = currentFrame else { return "--:--" }
        let date      = Date(timeIntervalSince1970: TimeInterval(frame.time))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // Index of the last non-nowcast frame — everything after is forecast
    private var nowcastStartIndex : Int? {
        frames.lastIndex(where: { !$0.isNowcast }).map { $0 + 1 }
    }

    var body: some View {
        ZStack(alignment: .leading) {

            // Pill background
            Capsule()
                .fill(.black.opacity(0.65))

            HStack(spacing: 12) {

                // Play / pause button
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
                            .offset(x: isPlaying ? 0 : 1)   // optical centering for play triangle
                    }
                }
                .buttonStyle(.plain)

                // Time label
                Text(timeLabel)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 44, alignment: .leading)

                // Custom slider with nowcast track coloring
                GeometryReader { geo in
                    ZStack(alignment: .leading) {

                        // Track background
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .frame(height: 4)

                        // Past frames track — white
                        if frameCount > 1 {
                            let pastWidth : CGFloat = {
                                guard let nowStart = nowcastStartIndex, nowStart > 0 else {
                                    return geo.size.width
                                }
                                return geo.size.width * CGFloat(nowStart) / CGFloat(frameCount)
                            }()
                            Capsule()
                                .fill(.white.opacity(0.6))
                                .frame(width: pastWidth, height: 4)

                            // Nowcast / forecast track — accent color
                            if let nowStart = nowcastStartIndex, nowStart < frameCount {
                                let forecastWidth = geo.size.width - pastWidth
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.7))
                                    .frame(width: forecastWidth, height: 4)
                                    .offset(x: pastWidth)
                            }
                        }

                        // Thumb
                        let thumbX : CGFloat = frameCount > 1
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
                                        let index    = Int((fraction * Double(frameCount - 1)).rounded())
                                        setIndex(index)
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
        .onChange(of: currentIndex) { _, newIndex in
            sliderValue = Double(newIndex)
        }
    }

    // ── Private ───────────────────────────────────────────────

    private func stepForward() {
        if mode == .radar { viewModel.advanceRadarFrame() }
        else              { viewModel.advanceSatelliteFrame() }
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
