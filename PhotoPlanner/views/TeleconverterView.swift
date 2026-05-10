//
//  TeleconverterView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 10.05.26.
//

import SwiftUI


struct TeleconverterView: View {
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(\.dismiss)              private var dismiss
    @Environment(PhotoPlannerModel.self) private var model
    
    @State private var tc1Factor: Double = Properties.instance.tc1Factor!
    @State private var tc2Factor: Double = Properties.instance.tc2Factor!
    
    
    var body: some View {
        VStack {
            HStack(spacing: 10) {
                
                Spacer()
                
                Button("Close") {
                    
                    dismiss()
                }
            }
            .buttonStyle(.glass)
            .padding()
            
            
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
            
            Spacer()
        }
        .padding()
        /*
        .onDisappear {
            self.model.tc1.factor         = self.tc1Factor
            Properties.instance.tc1Factor = self.tc1Factor
            
            self.model.tc2.factor         = self.tc2Factor
            Properties.instance.tc2Factor = self.tc2Factor
            
            self.model.updateApertureAndFocalLength()
        }
        */
    }
}
