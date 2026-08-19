//
//  CloudMapView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 24.07.26.
//

import Foundation
import SwiftUI
import MapKit


struct CloudMapView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss)     private var dismiss

    @State private var viewModel  : CloudMapViewModel = CloudMapViewModel()
    @State private var activeMode : CloudMapMode      = .cloud

    let coordinate                : CLLocationCoordinate2D
    let apiKey                    : String

    private var isLoading: Bool {
        switch activeMode {
            case .cloud:
                if case .loading = viewModel.cloudState { return true }
                return false
            case .radar:
                return viewModel.radarLoading
            case .satellite:
                return viewModel.satelliteLoading
    }
    }

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button {
                        Task {
                            switch activeMode {
                                case .cloud     : await viewModel.loadCloud(coordinate: coordinate, apiKey: apiKey, scale: UITraitCollection.current.displayScale)
                                case .radar     : await viewModel.loadRadarFrames(coordinate: coordinate, scale: UITraitCollection.current.displayScale)
                                case .satellite : await viewModel.loadSatelliteFrames(coordinate: coordinate, scale: UITraitCollection.current.displayScale)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    }
                    .disabled(isLoading)

                    Spacer()

                    Picker("Mode", selection: $activeMode) {
                        ForEach(CloudMapMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260) // was 200

                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                }
                .padding()

                switch activeMode {
                    case .cloud:
                        switch viewModel.cloudState {
                            case .idle:
                                EmptyView()
                            case .loading:
                                VStack(spacing: 12) {
                                    ProgressView()
                                    Text("Loading cloud map…")
                                        .font(.caption)
                                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                                }
                            case .loaded(let image):
                                VStack(spacing: 12) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    HStack(spacing: 6) {
                                        Image(systemName: CloudMapMode.cloud.icon)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(CloudMapMode.cloud.attribution)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(String(format: "%.6f°N  %.6f°E", coordinate.latitude, coordinate.longitude))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
                                }
                            case .failed(let message):
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.largeTitle)
                                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                                    Text(message)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                                }
                                .padding()
                        }
                    case .radar:
                        AnimatedFrameView(viewModel: viewModel, mode: .radar, coordinate: coordinate)
                    case .satellite:
                        AnimatedFrameView(viewModel: viewModel, mode: .satellite, coordinate: coordinate)
                }
            }
            .padding()
        }
        .presentationDetents([.height(560)]) // was 500
        .presentationDragIndicator(.visible)
        .task {
            // Load both tabs in parallel so switching is instant
            await viewModel.loadAll(coordinate: coordinate, apiKey: apiKey, scale: UITraitCollection.current.displayScale)
        }
    }
}
