//
//  LensDetailView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.04.26.
//

import SwiftUI
import SwiftData


struct LensDetailView: View {
    @Environment(\.colorScheme)          var colorScheme
    @Environment(PhotoPlannerModel.self) private var model
    @Environment(\.modelContext)         private var context
    @Environment(\.dismiss)              private var dismiss
    
    @State private var name           : String = "Lens"
    @State private var minFocalLength : Int    = 8
    @State private var maxFocalLength : Int    = 1200
    @State private var minAperture    : Double = 0.7
    @State private var maxAperture    : Double = 22.0

    let lens: Lens
    
    var body: some View {
        Form {
            HStack {
                Text("Name")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                TextField("Enter name", text: $name)
                    .textFieldStyle(.plain)
                    .font(Constants.REGULAR_FONT_16)
                    .cornerRadius(6)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .accentColor(.accentColor)
            }
            .background(self.colorScheme == .dark ? .black : .white)
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            
            HStack {
                Text("Min Focal Length")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                Picker("", selection: $minFocalLength) {
                    ForEach(Array(stride(from: 8, through: 1200, by: 1)), id: \.self) { index in
                        Text("\(index, specifier: "%d") mm")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
            }
            .background(self.colorScheme == .dark ? .black : .white)
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            
            HStack {
                Text("Max Focal Length")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                Picker("", selection: $maxFocalLength) {
                    ForEach(Array(stride(from: 8, through: 1200, by: 1)), id: \.self) { index in
                        Text("\(index, specifier: "%d") mm")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
            }
            .background(self.colorScheme == .dark ? .black : .white)
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            
            HStack {
                Text("Min Aperture")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                Picker("", selection: $minAperture) {
                    ForEach(Array(stride(from: 0.7, through: 22.0, by: 0.1)), id: \.self) { index in
                        Text("\(index, specifier: "%.1f")")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
            }
            .background(self.colorScheme == .dark ? .black : .white)
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            
            HStack {
                Text("Max Aperture")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                Picker("", selection: $maxAperture) {
                    ForEach(Array(stride(from: 0.7, through: 22, by: 0.1)), id: \.self) { index in
                        Text("\(index, specifier: "%.1f")")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
            }
            .background(self.colorScheme == .dark ? .black : .white)
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
                                    
            Button("Update") {
                lens.name           = name
                lens.minFocalLength = minFocalLength
                lens.maxFocalLength = maxFocalLength
                lens.minAperture    = Double(minAperture)
                lens.maxAperture    = Double(maxAperture)

                do {
                    try context.save()
                    if self.model.lens.id == lens.id {
                        self.model.lens = lens
                    }
                } catch {
                    print(error.localizedDescription)
                }
                
                dismiss()
            }
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            .foregroundStyle(self.colorScheme == .dark ? .white : .black)
            .buttonStyle(.bordered)
        }
        .scrollContentBackground(.hidden)
        .background(self.colorScheme == .dark ? .black : .white)
        .onAppear {
            self.name           = lens.name
            self.minFocalLength = lens.minFocalLength
            self.maxFocalLength = lens.maxFocalLength
            self.minAperture    = lens.minAperture
            self.maxAperture    = lens.maxAperture
        }
    }
}
