//
//  FieldOfViewCalculatorView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.05.26.
//

import Foundation
import SwiftUI


struct MinimumDistanceCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State                  private var viewModel         : FieldOfViewCalculatorViewModel
    @State                  private var showFovCalculator : Bool = false
    
    let focalLength    : Double
    let sensorWidth    : Double
    let sensorHeight   : Double
    let selectedCamera : Camera
    let selectedLens   : Lens
    
    
    init(photoPlannerModel: PhotoPlannerModel) {
        self.focalLength    = photoPlannerModel.focalLength
        self.sensorWidth    = SensorFormat.fromId(photoPlannerModel.camera.sensorFormat)?.width  ?? SensorFormat.fullFormat.width
        self.sensorHeight   = SensorFormat.fromId(photoPlannerModel.camera.sensorFormat)?.height ?? SensorFormat.fullFormat.height
        self.selectedCamera = photoPlannerModel.camera
        self.selectedLens   = photoPlannerModel.lens
        _viewModel = State(initialValue: FieldOfViewCalculatorViewModel(focalLength: focalLength, sensorWidth: sensorWidth, sensorHeight: sensorHeight))
    }

    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("Min. Distance Calculator")
                        .font(Constants.REGULAR_FONT_18)
                    
                    Spacer()
                    
                    Button {
                        showFovCalculator = true
                    } label: {
                        Image(systemName: "viewfinder")
                    }
                    .sheet(isPresented: $showFovCalculator) {
                        FovCalculatorView(camera: self.selectedCamera, lens: self.selectedLens)
                    }
                    
                    Button("Close") {
                        dismiss()
                    }
                }
                .buttonStyle(.glass)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                cameraInfoCard

                orientationCard

                fieldSizeCard

                resultCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .presentationDragIndicator(.visible)
    }

    
    private var cameraInfoCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "camera")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f mm", focalLength))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(String(format: "Sensor %.0f × %.0f mm", sensorWidth, sensorHeight))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // FOV angles
            VStack(alignment: .trailing, spacing: 2) {
                if viewModel.orientation == .landscape {
                    Text(String(format: "H: %.1f°", viewModel.horizontalFOV * 180 / .pi))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(String(format: "V: %.1f°", viewModel.verticalFOV * 180 / .pi))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(format: "H: %.1f°", viewModel.verticalFOV * 180 / .pi))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(String(format: "V: %.1f°", viewModel.horizontalFOV * 180 / .pi))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    
    private var orientationCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader(title: "ORIENTATION", subtitle: "Landscape or portrait frame", color: .blue)

            Picker("Orientation", selection: Binding(
                get: { viewModel.orientation },
                set: { viewModel.orientationChanged(to: $0) }
            )) {
                ForEach(CameraOrientation.allCases, id: \.self) { orientation in
                    Label(orientation.rawValue, systemImage: orientation.icon)
                        .tag(orientation)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }


    private var fieldSizeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "SUBJECT SIZE", subtitle: "Drag to set the field of view", color: .purple)

            // Width slider
            fieldSlider(label: "Width", icon: "arrow.left.and.right", value: viewModel.fieldWidthSlider, fieldMetres: viewModel.fieldWidth, isActive: viewModel.activeAxis == .horizontal, color: .purple) { value in
                viewModel.widthSliderChanged(to: value)
            }

            // Link indicator
            HStack {
                Spacer()
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Aspect ratio locked")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Height slider
            fieldSlider(label: "Height", icon: "arrow.up.and.down", value: viewModel.fieldHeightSlider, fieldMetres: viewModel.fieldHeight, isActive: viewModel.activeAxis == .vertical, color: .purple) { value in
                viewModel.heightSliderChanged(to: value)
            }

            // Visual frame representation
            frameVisualisation
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }


    private func fieldSlider(label: String, icon: String, value: Double, fieldMetres: Double, isActive: Bool, color: Color, onChanged: @escaping (Double) -> Void) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(isActive ? color : .secondary)
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(isActive ? color : .secondary)
                Spacer()
                Text(FieldOfViewCalculator.formatFieldSize(fieldMetres))
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isActive ? color : .primary)
                    .animation(.none, value: fieldMetres)
            }

            Slider(value: Binding(
                get: { value },
                set: { onChanged($0) }
            ), in: 0...1)
            .tint(isActive ? color : .secondary.opacity(0.5))
        }
    }
    

    private var frameVisualisation: some View {
        GeometryReader { geo in
            let maxWidth  : CGFloat = geo.size.width - 32
            let ratio     : CGFloat = self.viewModel.aspectRatio
            let frameSize : CGSize  = calcFrameSize(ratio: ratio, maxWidth: maxWidth)
            let frameW    : CGFloat = frameSize.width
            let frameH    : CGFloat = frameSize.height
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.purple.opacity(1.0), lineWidth: 1.5)
                    .frame(width: frameW, height: frameH)

                // Width annotation
                VStack {
                    HStack {
                        Text(FieldOfViewCalculator.formatFieldSize(viewModel.fieldWidth))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.purple)
                            .fixedSize()
                    }
                    .frame(width: frameW)
                    Spacer()
                }
                .frame(width: frameW, height: frameH + 20)
                .offset(y: -10)

                // Height annotation
                VStack(alignment: .center) {
                    Text(FieldOfViewCalculator.formatFieldSize(viewModel.fieldHeight))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.purple)
                        .rotationEffect(.degrees(90))
                        .fixedSize()
                }
                .frame(height: frameH)
                .offset(x: frameW * 0.5 + 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(frameH + 20, 60))
        }
        .frame(height: 90)
    }
    
    
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionHeader(title: "MINIMUM DISTANCE", subtitle: "How far you need to be from your subject", color: .orange)

            Text(FieldOfViewCalculator.formatDistance(viewModel.minimumDistance))
                .font(.system(size: 48, weight: .black).monospacedDigit())
                .foregroundStyle(.orange)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

            // Additional context
            HStack(spacing: 20) {
                contextValue(label: "Field width", value: FieldOfViewCalculator.formatFieldSize(viewModel.fieldWidth), icon: "arrow.left.and.right")
                Divider().frame(height: 30)
                contextValue(label: "Field height", value: FieldOfViewCalculator.formatFieldSize(viewModel.fieldHeight), icon: "arrow.up.and.down")
            }
            .padding(.horizontal, 8)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    
    private func sectionHeader(title: String, subtitle: String, color: Color) -> some View {
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
    }

    private func contextValue(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func calcFrameSize(ratio: CGFloat, maxWidth: CGFloat) -> CGSize {
        if ratio >= 1 {
            return CGSize(width: min(maxWidth, 80), height: min(maxWidth, 80) / ratio)
        } else {
            return CGSize(width: min(maxWidth, 80) * ratio, height: min(maxWidth, 80))
        }
    }
}
