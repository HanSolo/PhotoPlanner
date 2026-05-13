//
//  MoonPhaseMapOverlay.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.05.26.
//

import Foundation
import SwiftUI


struct MoonPhaseMapOverlay: View {
    @Bindable var vm: MoonViewModel

    var body: some View {
        if let phase = vm.moonPhase {
            MoonPhaseOverlayView(phase: phase)
                .padding(.horizontal, 10)  // side margins only
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
                //.onTapGesture { withAnimation { vm.dismiss() } }
        }
    }
}
