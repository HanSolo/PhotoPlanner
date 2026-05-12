//
//  MilkywayMapOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 12.05.26.
//

import Foundation
import SwiftUI


// Overlay wrapper
struct MilkywayMapOverlay: View {
    @Bindable var vm: MilkywayViewModel

    var body: some View {
        if let tl = vm.timeline {
            GeometryReader { geometry in
                MilkywayOverlayView(timeline: tl)
                    .padding(.horizontal, 10)  // side margins only
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
                    //.onTapGesture { withAnimation { vm.dismiss() } }
                    .frame(width: geometry.size.width - 100)
                    .offset(x: 50, y: 100)
            }
        }
    }
}
