//
//  MilkywayMapOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 16.06.26.
//
import Foundation
import SwiftUI
import CoreLocation


struct MilkywayMapOverlayView: View {
    let viewModel : MilkywayMapViewModel
    let onClose   :   () -> Void

    var body: some View {        
        MilkywayCanvasOverlay(viewModel: viewModel, onClose: onClose)
        .transition(.opacity)
    }
}
