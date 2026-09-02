//
//  TeleconverterView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 10.05.26.
//

import SwiftUI


struct SettingsView: View {
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(\.dismiss)              private var dismiss
    @Environment(PhotoPlannerModel.self) private var model
    
    @State private var tc1Factor      : Double   = Properties.instance.tc1Factor!
    @State private var tc2Factor      : Double   = Properties.instance.tc2Factor!
    @State private var observerHeight : Double   = Properties.instance.observerHeight!    
    
    static let observerHeights        : [Double] = {
        var heights: [Double] = []

        // 0.3m to 5m — increment 0.1m
        var h : Double = 0.3
        while h <= 5.0 {
            heights.append((h * 10).rounded() / 10)   // avoid floating point drift
            h += 0.1
        }

        // 5.5m to 20m — increment 0.5m
        h = 5.5
        while h <= 20.0 {
            heights.append(h)
            h += 0.5
        }

        // 21m to 100m — increment 1m
        h = 21.0
        while h <= 100.0 {
            heights.append(h)
            h += 1.0
        }

        // 105m to 500m — increment 5m
        h = 105.0
        while h <= 500.0 {
            heights.append(h)
            h += 5.0
        }

        return heights
    }()
    
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Settings")
                    .font(Constants.REGULAR_FONT_18)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .buttonStyle(.glass)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            HStack {
                Text("Teleconverter 1")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                Picker("", selection: $tc1Factor) {
                    ForEach(Array(stride(from: 1.0, through: 30.0, by: 0.1)), id: \.self) { index in
                        Text("\(index, specifier: "%.1f")")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: self.tc1Factor) { oldValue, newValue in
                    self.model.tc1.factor         = newValue
                    Properties.instance.tc1Factor = newValue
                }
            }
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            
            HStack {
                Text("Teleconverter 2")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                Picker("", selection: $tc2Factor) {
                    ForEach(Array(stride(from: 1.0, through: 30.0, by: 0.1)), id: \.self) { index in
                        Text("\(index, specifier: "%.1f")")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: self.tc2Factor) { oldValue, newValue in
                    self.model.tc2.factor         = newValue
                    Properties.instance.tc2Factor = newValue
                }
            }
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            
            Divider()
            
            HStack {
                Text("Observer Height")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                Picker("", selection: $observerHeight) {
                    ForEach(SettingsView.observerHeights, id: \.self) { height in
                        Text(SettingsView.formatObserverHeight(height))
                            .tag(height)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: self.observerHeight) { oldValue, newValue in
                    self.model.observerHeight          = newValue
                    Properties.instance.observerHeight = newValue
                }                
            }
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            
            Divider()
            
            HStack {
                Toggle(isOn: self.model.showWeatherRadarBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lightning strikes with weather radar")
                            .font(Constants.REGULAR_FONT_16)
                        Text("Display current weather radar on full screen")
                            .font(Constants.REGULAR_FONT_12)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            HStack {
                Toggle(isOn: self.model.desaturatedMapForRadarBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Desaturate map for radar overlay")
                            .font(Constants.REGULAR_FONT_16)
                        Text("Reduce color saturation of the map")
                            .font(Constants.REGULAR_FONT_12)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .backgroundStyle(.thinMaterial)
        .presentationDetents([.medium, .large])
        
    }
    
    
    static func formatObserverHeight(_ metres: Double) -> String {
        switch metres {
            case ..<10    : return String(format: "%.1f m", metres)
            case 10..<100 : return String(format: "%.0f m", metres)
            default       : return String(format: "%.0f m", metres)
        }
    }
}
