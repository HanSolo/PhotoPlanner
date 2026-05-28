//
//  WeatherMapOverlay.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//


import Foundation
import SwiftUI


struct WeatherMapOverlayView: View {
    @Bindable var viewModel : WeatherOverlayViewModel
              let onRefresh : () -> Void

    var body: some View {
        if viewModel.isVisible, let weather = viewModel.weather {
            WeatherOverlayView(weather: weather, isOutdated: viewModel.isOutdated, onRefresh: onRefresh, onDismiss: { withAnimation { viewModel.dismiss() } })
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
        }        
    }
}
