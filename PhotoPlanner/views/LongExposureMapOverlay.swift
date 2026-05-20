//
//  LongExposureMapOverlay.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.05.26.
//

import Foundation
import SwiftUI


struct LongExposureMapOverlay: View {
    @Bindable var viewModel: LongExposureViewModel

    var body: some View {
        if let timeline = viewModel.timeline {
            GeometryReader { geometry in
                LongExposureOverlayView(timeline: timeline)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
                    //.onTapGesture { withAnimation { viewModel.dismiss() } }
                    .frame(width: geometry.size.width - 100)
                    .offset(x: 50, y: 100)
            }
        }
    }
}
