//
//  FovCalculatorView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.08.26.
//

import Foundation
import SwiftUI


struct FovCalculatorView: View {
    @Environment(\.dismiss)     private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State                      private var vm : FovViewModel

    let camera : Camera
    let lens   : Lens
    

    init(camera: Camera, lens: Lens) {
        self.camera = camera
        self.lens   = lens
        self._vm    = State(initialValue: FovViewModel(camera: camera, lens: lens))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 1) {

                // Info strip
                infoStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Text("\(self.camera.name) / \(self.lens.name)")
                    .font(Constants.REGULAR_FONT_14)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                
                // Diagram
                FovDiagram(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                Divider()

                // Controls
                controlsPanel
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .navigationTitle("FOV & Depth of Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    // Orientation toggle
                    Button {
                        vm.isLandscape.toggle()
                    } label: {
                        Image(systemName: vm.isLandscape
                              ? "rectangle.landscape.rotate"
                              : "rectangle.portrait.rotate")
                        .font(.system(size: 16))
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // Info strip
    private var infoStrip: some View {
        let dof = vm.dof
        return HStack(spacing: 0) {
            infoCell(
                label: "Frame",
                value: String(format: "%.1f × %.1fm",
                              dof.frameWidthAtFocus,
                              dof.frameHeightAtFocus)
            )
            Divider().frame(height: 32)
            infoCell(
                label: "DOF",
                value: dof.farLimit.isInfinite
                    ? "∞"
                    : String(format: "%.2fm", dof.farLimit - dof.nearLimit)
            )
            Divider().frame(height: 32)
            infoCell(
                label: "Hyperfocal",
                value: String(format: "%.1fm", dof.hyperfocal)
            )
            Divider().frame(height: 32)
            infoCell(
                label: "CoC",
                value: String(format: "%.4fmm", dof.cocMm)
            )
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func infoCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // Controls panel
    private var controlsPanel: some View {
        VStack(spacing: 10) {

            // Focal length (hidden for prime lenses)
            if !lens.isPrime {
                sliderRow(
                    label:  "Focal Length",
                    value:  $vm.focalLength,
                    range:  vm.focalLengthRange,
                    format: "%.0f mm"
                )
            }

            // Aperture
            sliderRow(
                label:  "Aperture",
                value:  $vm.aperture,
                range:  vm.apertureRange,
                format: "f/%.1f"
            )

            // Focus distance
            sliderRow(
                label:  "Focus Distance",
                value:  $vm.focusDistance,
                range:  vm.focusDistanceRange,
                format: "%.1f m"
            )
        }
    }

    private func sliderRow(label : String, value : Binding<Double>, range : ClosedRange<Double>, format : String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Slider(value: value, in: range)
                .tint(.accentColor)

            Text(String(format: format, value.wrappedValue))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .frame(width: 64, alignment: .trailing)
        }
    }
}
