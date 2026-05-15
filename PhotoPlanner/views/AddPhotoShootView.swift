//
//  AddPhotoShootView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 14.05.26.
//

import SwiftUI
import CoreLocation
import SwiftData


struct AddPhotoShootView: View {
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(\.modelContext)         private var context
    @Environment(\.dismiss)              private var dismiss
    @Environment(PhotoPlannerModel.self) private var model
    
    @State private var name : String = ""
    @State private var note : String = ""
    
    
    var body: some View {
        VStack {
            HStack(spacing: 10) {
                
                Text("Add Photo Shoot")
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .buttonStyle(.glass)
            .padding()
            
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
                    Text("Note")
                        .font(Constants.REGULAR_FONT_16)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    Spacer()
                    TextField("Enter note", text: $note)
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
                    Text("Camera")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    Spacer()
                    Text("\(self.model.camera.name) (\(self.model.orientation.name))")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                }
                
                HStack {
                    Text("Lens")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    Spacer()
                    Text("\(self.model.lens.name) (f/\(String(format: "%.1f", self.model.aperture)), \(String(format: "%.0f", self.model.focalLength)) mm)")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                }
                
                HStack {
                    Text("Teleconverter 1 (\(String(format: "%.1f", self.model.tc1.factor)))")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    Spacer()
                    Text("Teleconverter 2 (\(String(format: "%.1f", self.model.tc2.factor)))")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                }
                
                HStack {
                    Text("Camera")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    Spacer()
                    Text("\(String(format: "%.8f", self.model.cameraMarkerData?.coordinate.latitude ?? 0)), \(String(format: "%.8f", self.model.cameraMarkerData?.coordinate.longitude ?? 0))")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                }
                
                HStack {
                    Text("Subject")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    Spacer()
                    Text("\(String(format: "%.8f", self.model.subjectMarkerData?.coordinate.latitude ?? 0)), \(String(format: "%.8f", self.model.subjectMarkerData?.coordinate.longitude ?? 0))")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                }
                
                HStack {
                    Spacer()
                    
                    Button("Save") {
                                            
                        let camera         : Camera = self.model.camera
                        let lens           : Lens   = self.model.lens
                        let isLandscape    : Bool   = self.model.orientation == .landscape
                        let aperture       : Double = self.model.aperture
                        let focalLength    : Double = self.model.focalLength
                        let tc1            : Double = self.model.tc1.factor
                        let tc2            : Double = self.model.tc2.factor
                        let cameraLat      : Double = self.model.cameraMarkerData?.coordinate.latitude   ?? 0
                        let cameraLon      : Double = self.model.cameraMarkerData?.coordinate.longitude  ?? 0
                        let subjectLat     : Double = self.model.subjectMarkerData?.coordinate.latitude  ?? 0
                        let subjectLon     : Double = self.model.subjectMarkerData?.coordinate.longitude ?? 0
                        let cameraDistance : Double = self.model.cameraDistance
                                                        
                        let photoShoot = PhotoShoot(name: self.name, note: self.note, camera: camera, lens: lens, isLandscape: isLandscape, aperture: aperture,
                                                    focalLength: focalLength, tc1: tc1, tc2: tc2, cameraLat: cameraLat, cameraLon: cameraLon,
                                                    subjectLat: subjectLat, subjectLon: subjectLon, cameraDistance: cameraDistance)
                        context.insert(photoShoot)
                        do {
                            try context.save()
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .buttonStyle(.glass)
                }
            }
            .scrollContentBackground(.hidden)
            .background(self.colorScheme == .dark ? .black : .white)
            
            Spacer()
        }
    }
}

