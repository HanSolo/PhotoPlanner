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
        }        
    }

    private func scheduleAutoDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(15))
            withAnimation(.easeOut(duration: 0.3)) { viewModel.dismiss() }
        }
    }
}
