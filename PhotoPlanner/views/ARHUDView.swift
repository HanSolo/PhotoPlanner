//
//  ARHUD.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine

struct ARHUDView: View {
    let viewModel          : ARViewModel
    let coordinate         : CLLocationCoordinate2D
    let onClose            : () -> Void
    let onStartCalibrate   : () -> Void
    let onConfirmCalibrate : () -> Void
    let onCancelCalibrate  : () -> Void

    private var sunPosition : SunPosition {
        SolarCalculator.calcSunPosition(at: coordinate, time: viewModel.selectedTime)
    }
    private var moonInfo    : (altitude: Double, azimuth: Double) {
        MoonCalculator.calcMoonPosition(at: coordinate, time: viewModel.selectedTime)
    }

    
    var body: some View {
        VStack(spacing: 0) {

            // Top bar (close and calibration status)
            HStack {
                // Calibration status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.headingSource.isManuallyCalibrated ? .green : .yellow)
                        .frame(width: 8, height: 8)
                    Text(viewModel.calibrationStatus)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial.opacity(0.8))
                .clipShape(Capsule())

                Spacer()

                // Calibrate button
                if !viewModel.isCalibrating {                
                    Button {
                        onStartCalibrate()
                    } label: {
                        Image(systemName: viewModel.headingSource.isManuallyCalibrated ? "scope" : "plus.viewfinder")
                            .padding(7)
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    
                }

                // Close button
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .buttonStyle(.glass)
                .clipShape(Circle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            // Calibration confirmation banner
            if viewModel.isCalibrating {
                VStack(spacing: 8) {
                    Text("Point phone at true north")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Hold steady, then tap Confirm")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            onCancelCalibrate()
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .clipShape(Capsule())
                        .buttonStyle(.glass)

                        Button("Confirm") {
                            onConfirmCalibrate()
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .clipShape(Capsule())
                        .buttonStyle(.glass)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }

            // Info box
            if !viewModel.isCalibrating {
                HStack(spacing: 16) {
                    // Sun info
                    celestialInfoPill(symbol: "☀️", altitude: sunPosition.altitude, azimuth: sunPosition.azimuth, label: sunLabel)

                    // Moon info
                    let moonPhase = MoonCalculator.calcMoonPhase(at: coordinate, time: viewModel.selectedTime, timeZone: TimeZone.current)
                    celestialInfoPill(symbol: moonPhase.phaseName.symbol, altitude: moonInfo.altitude, azimuth: moonInfo.azimuth, label: moonPhase.phaseName.rawValue)
                }
                .padding(.bottom, 12)
            }

            // Time slider
            if !viewModel.isCalibrating {
                ARTimeSliderView(
                    selectedTime: Binding(
                        get: { viewModel.selectedTime },
                        set: { viewModel.updateSelectedTime($0) }
                    ),
                    onTimeChanged: { time in
                        viewModel.updateIndicatorPositions()
                    },
                    onTimeScrubEnded: { time in
                        // Rebuild full arcs only when scrubbing ends
                        // to avoid rebuilding 60 times per second
                        viewModel.updateSelectedTimeAndRebuild(time)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func celestialInfoPill(symbol: String, altitude: Double, azimuth: Double, label: String) -> some View {
        HStack(spacing: 6) {
            Text(symbol).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                Text(String(format: "%.0f° alt · %.0f° az", altitude, azimuth))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.8))
        .clipShape(Capsule())
    }

    private var sunLabel: String {
        let altitude : Double = sunPosition.altitude
        switch altitude {
            case ..<(-6)  : return "Below horizon"
            case (-6)..<0 : return "Blue hour"
            case 0..<6    : return "Golden hour"
            default       : return "Daylight"
        }
    }
}
