//
//  ScrubberView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 18.08.26.
//

import Foundation
import SwiftUI


struct ScrubberView: View {
    let viewModel : CloudMapViewModel
    let mode      : CloudMapMode

    private var frames       : [CloudMapFrame] { mode == .radar ? viewModel.radarFrames       : viewModel.satelliteFrames       }
    private var currentIndex : Int             { mode == .radar ? viewModel.radarCurrentIndex : viewModel.satelliteCurrentIndex }

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 2) {
                ForEach(frames.indices, id: \.self) { index in
                    let frame     : CloudMapFrame = frames[index]
                    let isCurrent : Bool          = index == currentIndex
                    Rectangle()
                        .fill(segmentColor(for: frame, isCurrent: isCurrent))
                        .frame(maxWidth: .infinity)
                        .frame(height: isCurrent ? 8 : 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .animation(.easeInOut(duration: 0.15), value: isCurrent)
                        .onTapGesture {
                            if mode == .radar {
                                viewModel.radarPlaying       = false
                                viewModel.radarCurrentIndex  = index
                            } else {
                                viewModel.satellitePlaying       = false
                                viewModel.satelliteCurrentIndex  = index
                            }
                        }
                }
            }
            .frame(height: 10)
        }
        .frame(height: 10)
    }

    private func segmentColor(for frame: CloudMapFrame, isCurrent: Bool) -> Color {
        if isCurrent { return .white }
        if frame.isNowcast { return .blue.opacity(0.5) }
        return .white.opacity(0.3)
    }
}
