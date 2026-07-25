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
    
    @State private var viewModel = CloudMapViewModel()
    
    let coordinate : CLLocationCoordinate2D
    let apiKey     : String

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button {
                        Task { await viewModel.load(coordinate: coordinate, apiKey: apiKey, scale: UITraitCollection.current.displayScale) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    }
                    .disabled({
                        if case .loading = viewModel.state { return true }
                        return false
                    }())
                    
                    Spacer()
                    
                    Text("Cloud Cover Overlay")
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                }
                .padding()
                
                switch viewModel.state {
                    case .idle:
                        EmptyView()

                    case .loading:
                        ProgressView()
                        Text("Loading cloud map…")
                            .font(.caption)
                            .foregroundStyle(self.colorScheme == .dark ? .white : .black)

                    case .loaded(let image):
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                            Text(String(format: "%.6f°N  %.6f°E", coordinate.latitude, coordinate.longitude))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                                .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))

                    case .failed(let message):
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                            Text(message)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                }
            }
            .padding()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.load(coordinate: coordinate, apiKey: apiKey, scale: UITraitCollection.current.displayScale)
        }
    }
}
