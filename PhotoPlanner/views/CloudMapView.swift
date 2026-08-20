//
//  CloudMapView.swift
//  PhotoPlanner
//

import Foundation
import SwiftUI
import MapKit


struct CloudMapView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss)     private var dismiss

    @State private var viewModel  : CloudMapViewModel = CloudMapViewModel()
    @State private var activeMode : CloudMapMode      = .radar

    let coordinate : CLLocationCoordinate2D

    private var isLoading: Bool {
        switch activeMode {
            case .radar     : return viewModel.radarLoading
            case .satellite : return viewModel.satelliteLoading
        }
    }

    var body: some View {
        ZStack {
            VStack {
                // Toolbar
                HStack {
                    // Refresh
                    Button {
                        Task {
                            switch activeMode {
                                case .radar     : await viewModel.loadRadarFrames(coordinate: coordinate, scale: UITraitCollection.current.displayScale)
                                case .satellite : await viewModel.loadSatelliteFrames(coordinate: coordinate, scale: UITraitCollection.current.displayScale)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                    .disabled(isLoading)

                    Spacer()

                    // Mode picker
                    Picker("Mode", selection: $activeMode) {
                        ForEach(CloudMapMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)

                    Spacer()

                    // Wind toggle
                    Button {
                        viewModel.windVisible.toggle()
                        if viewModel.windVisible && viewModel.windSamples.isEmpty {
                            Task { await viewModel.loadWind(coordinate: coordinate) }
                        }
                    } label: {
                        Image(systemName: viewModel.windVisible ? "wind" : "wind")
                            .foregroundStyle(
                                viewModel.windLoading ? .secondary :
                                viewModel.windVisible ? Color.accentColor :
                                (colorScheme == .dark ? .white : .black)
                            )
                            .overlay(
                                viewModel.windLoading
                                    ? ProgressView().scaleEffect(0.6)
                                    : nil
                            )
                    }
                    .disabled(viewModel.windLoading)
                    .padding(.trailing, 8)

                    // Close
                    Button("Close") { dismiss() }
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
                .padding()

                // Content
                switch activeMode {
                    case .radar     : AnimatedFrameView(viewModel: viewModel, mode: .radar, coordinate: coordinate)
                    case .satellite : AnimatedFrameView(viewModel: viewModel, mode: .satellite, coordinate: coordinate)
                }

                Spacer()
            }
            .padding()
        }
        .presentationDetents([.height(560)])
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.loadAll(
                coordinate: coordinate,
                scale:      UITraitCollection.current.displayScale
            )
        }
    }
}
