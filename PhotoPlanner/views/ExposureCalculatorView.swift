//
//  ExposureCalculatorView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 22.05.26.
//

import Foundation
import SwiftUI


struct ExposureCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State                  private var viewModel    : ExposureCalculatorViewModel
    @State                  private var ndFilterName : String = ""

    let baseAperture : Double
    
    
    init(baseAperture: Double) {
        self.baseAperture = baseAperture
        _viewModel = State(initialValue : ExposureCalculatorViewModel(baseAperture: baseAperture))
    }

    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("Exposure Calculator")
                        .font(Constants.REGULAR_FONT_18)
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                }
                .buttonStyle(.glass)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                // Setup 1
                setupCard(title: "BASE EXPOSURE", subtitle: "Measure without filter", color: .blue, content: { setup1Content })

                Image(systemName: "arrow.down")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)

                // Setup 2
                setupCard(
                    title:    "FILTERED SHOT",
                    subtitle: "Adjust for your ND filter",
                    color:    .purple,
                    content:  { setup2Content }
                )

                // Result
                resultCard
            }
            .backgroundStyle(.thinMaterial)
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).opacity(0.01))
        .backgroundStyle(.thinMaterial)
        .presentationDragIndicator(.visible)
    }

    
    private func setupCard<Content: View>(title: String, subtitle: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4, height: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                        .kerning(1.0)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    
    // Setup 1
    @ViewBuilder
    private var setup1Content: some View {
        HStack(spacing: 0) {
            pickerColumn(label: "Aperture", icon: "camera.aperture", color: .blue) {
                Picker("", selection: $viewModel.setup1ApertureIndex) {
                    ForEach(PhotoValues.apertures.indices, id: \.self) { index in
                        Text(PhotoValues.formatAperture(PhotoValues.apertures[index]))
                            .tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }

            divider

            pickerColumn(label: "Shutter", icon: "clock", color: .blue) {
                Picker("", selection: $viewModel.setup1ShutterIndex) {
                    ForEach(PhotoValues.shutterSpeeds.indices, id: \.self) { index in
                        Text(PhotoValues.formatShutter(PhotoValues.shutterSpeeds[index]))
                            .tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }

            divider

            pickerColumn(label: "ISO", icon: "square.stack", color: .blue) {
                Picker("", selection: $viewModel.setup1ISOIndex) {
                    ForEach(PhotoValues.isos.indices, id: \.self) { index in
                        Text(PhotoValues.formatISO(PhotoValues.isos[index]))
                            .tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .minimumScaleFactor(0.4)
            }
        }
        
        HStack {
            Spacer()
            Text(String(format: "EV %.1f", viewModel.baseEV))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.blue.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    // Setup 2
    @ViewBuilder
    private var setup2Content: some View {
        VStack(spacing: 0) {
            Picker("Calculate", selection: $viewModel.setup2Mode) {
                ForEach(Setup2Mode.allCases, id: \.self) { mode in
                    Text("Calculate \(mode.rawValue)").tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            HStack(spacing: 0) {
                pickerColumn(label: "Aperture", icon: "camera.aperture", color: .purple) {
                    Picker("", selection: $viewModel.setup2ApertureIndex) {
                        ForEach(PhotoValues.apertures.indices, id: \.self) { index in
                            Text(PhotoValues.formatAperture(PhotoValues.apertures[index]))
                                .tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }
                
                divider
                
                pickerColumn(label: "ND Filter", icon: "circle.lefthalf.filled", color: .purple) {
                    Picker("", selection: $viewModel.setup2NDStops) {
                        ForEach(PhotoValues.ndStops, id: \.self) { stops in
                            Text(stops == 0 ? "None" : "\(stops) stop\(stops == 1 ? "" : "s")")
                                .tag(stops)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .onChange(of: viewModel.setup2NDStops) {
                        self.ndFilterName = PhotoValues.ndFilterNames[viewModel.setup2NDStops]
                    }
                }
                
                divider
                
                if viewModel.setup2Mode == .shutter {
                    pickerColumn(label: "ISO", icon: "square.stack", color: .purple) {
                        Picker("", selection: $viewModel.setup2ISOIndex) {
                            ForEach(PhotoValues.isos.indices, id: \.self) { index in
                                Text(PhotoValues.formatISO(PhotoValues.isos[index]))
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .minimumScaleFactor(0.4)
                    }
                    .id("iso-picker")
                } else {
                    pickerColumn(label: "Shutter", icon: "clock", color: .purple) {
                        Picker("", selection: $viewModel.setup2ShutterIndex) {
                            ForEach(PhotoValues.shutterSpeeds.indices, id: \.self) { index in
                                Text(PhotoValues.formatShutter(PhotoValues.shutterSpeeds[index]))
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                    .id("shutter-picker")
                }
            }            
            
            HStack {
                Spacer()
                Text(self.ndFilterName.isEmpty ? "No filter" : self.ndFilterName)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.08))
                    .clipShape(Capsule())
                
                Spacer()
            }
        }
    }

    
    // Setup
    private var resultCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(resultColor)
                    .frame(width: 4, height: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(resultTitle)
                        .font(.caption.bold())
                        .foregroundStyle(resultColor)
                        .kerning(1.0)
                    Text("Set this on your camera for setup 2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Result value
            Text(resultValue)
                .font(.system(size: 36, weight: .black).monospacedDigit())
                .foregroundStyle(resultColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

            // ISO warning if applicable
            if viewModel.setup2Mode == .iso {
                isoWarningView
            }

            // Stops difference
            let stops = viewModel.stopsDifference
            HStack(spacing: 4) {
                Image(systemName: stops >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(stops >= 0 ? .orange : .green)
                Text(String(format: "%+.1f stops from base exposure", stops))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(resultColor.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.setup2Mode)
    }

    
    @ViewBuilder
    private var isoWarningView: some View {
        switch viewModel.calculatedISOWarning {
            case .belowBase    : warningPill(text: "Below base ISO — not achievable", color: .red)
            case .highNoise    : warningPill(text: "High ISO — expect increased noise", color: .yellow)
            case .extremeNoise : warningPill(text: "Extreme ISO — significant noise", color: .red)
            case .none         :EmptyView()
        }
    }

    private func warningPill(text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var resultTitle: String {
        switch viewModel.setup2Mode {
            case .shutter : return "REQUIRED SHUTTER SPEED"
            case .iso     : return "REQUIRED ISO"
        }
    }

    private var resultValue: String {
        switch viewModel.setup2Mode {
            case .shutter : return viewModel.calculatedShutterFormatted
            case .iso     : return PhotoValues.formatISO(viewModel.calculatedISO)
        }
    }

    private var resultColor: Color {
        switch viewModel.setup2Mode {
            case .shutter : return viewModel.calculatedShutterColor
            case .iso     : return viewModel.calculatedISOColor
        }
    }

    private func pickerColumn<Content: View>(label: String, icon: String, color: Color, @ViewBuilder picker: () -> Content) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            picker()
                .clipped()
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.5))
            .frame(width: 0.5)
            .frame(height: 140)
    }
}
