//
//  ARView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//

import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


struct ARView: View {
    @State        private var viewModel        : ARViewModel        = ARViewModel()
    @StateObject  private var locationProvider : ARLocationProvider = ARLocationProvider()

    let coordinate : CLLocationCoordinate2D
    let onClose    : () -> Void
    
    
    var body: some View {
        ZStack {
            // AR camera feed + scene
            ARSceneViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            // HUD overlay
            ARHUDView(viewModel: viewModel,coordinate: coordinate,
                onClose: {
                    viewModel.teardown()
                    onClose()
                },
                onStartCalibrate:    { viewModel.startCalibration() },
                onConfirmCalibrate:  { viewModel.confirmCalibration() },
                onCancelCalibrate:   { viewModel.cancelCalibration() }
            )
        }
        .onChange(of: locationProvider.currentLocation) { _, location in
            guard let location else { return }
            viewModel.updateLocation(location)
            viewModel.rebuildScene()
        }
        .onAppear {
            // Set initial time to now
            viewModel.selectedTime = Date()
        }
        .onDisappear {
            viewModel.teardown()
        }
        // Prevent screen from sleeping during AR session
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .statusBarHidden(true)
    }
}
