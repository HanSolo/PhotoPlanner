//
//  AddCameraView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 30.04.26.
//

import SwiftUI
import SwiftData


struct AddCameraView: View {
    @Environment(\.colorScheme)          var colorScheme
    @Environment(PhotoPlannerModel.self) private var model
    @Environment(\.modelContext)         private var context
    @Environment(\.dismiss)              private var dismiss
    
    @State private var name         : String = ""
    @State private var sensorFormat : Int    = 1
    
    
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
                Text("Sensor Format")
                    .font(Constants.REGULAR_FONT_16)
                    .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                Spacer()
                Picker("", selection: $sensorFormat) {
                    ForEach(Array(stride(from: 0, through: 8, by: 1)), id: \.self) { index in
                        Text("\(SensorFormat.allCases[index].name)")
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
            }
            .background(self.colorScheme == .dark ? .black : .white)
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
                                                            
            Button("Save") {
                let camera : Camera = Camera(name: self.name, sensorFormat: self.sensorFormat)
                context.insert(camera)
                do {
                    try context.save()
                } catch {
                    print(error.localizedDescription)
                }
                dismiss()
            }
            .disabled(name.isEmpty)
            .listRowBackground(self.colorScheme == .dark ? Color.black : Color.white)
            .foregroundStyle(self.colorScheme == .dark ? .white : .black)
            .buttonStyle(.bordered)
        }
        .scrollContentBackground(.hidden)
        .background(self.colorScheme == .dark ? .black : .white)
    }
}
