//
//  SunQualityMapOverlay.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation
import SwiftUI


struct SunQualityMapOverlayView: View {
    @Bindable var viewModel: SunQualityViewModel

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            if let daily = viewModel.dailyTimeline {
                DailyQualityOverlayView(timeline: daily)
                    .padding(.horizontal, 10)  // side margins only
                    .padding(.bottom, 10)
                    //.transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
                    //.onTapGesture { withAnimation { viewModel.dismiss() } }
                    //.onAppear { scheduleAutoDismiss() }
            }

            if viewModel.isLoading {
                ProgressView()
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(12)
                    //.transition(.opacity)
            }
        }
        //.animation(.easeInOut(duration: 0.25), value: vm.dailyTimeline != nil)
        //.animation(.easeInOut(duration: 0.2),  value: vm.isLoading)
    }

    private func scheduleAutoDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(15))
            withAnimation(.easeOut(duration: 0.3)) { viewModel.dismiss() }
        }
    }
}
