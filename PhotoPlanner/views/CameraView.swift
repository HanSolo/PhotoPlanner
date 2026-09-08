//
//  CameraView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 30.04.26.
//

import SwiftUI
import SwiftData


struct CameraView: View {
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(\.modelContext)         private var context
    @Environment(\.dismiss)              private var dismiss
    @Environment(PhotoPlannerModel.self) private var model
    
    @State                               private var addCameraViewVisible : Bool = false
    @State                               private var cameraInUseAlert     : Bool = false
    
    @Query                               private var photoShoots          : [PhotoShoot]
    
    let cameras : [Camera]

        
    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 10) {
                    Button("Add Camera") {
                        self.addCameraViewVisible = true
                    }
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                }
                .buttonStyle(.glass)
                .padding()
            }
            
            List {
                ForEach(cameras, id: \.id) { camera in
                    NavigationLink(value: camera) {
                        HStack(spacing: .some(15)) {
                            Button {
                            } label: {
                                Image(systemName: camera.id == self.model.camera.id ? "checkmark.circle.fill" : "checkmark.circle")
                            }
                            .highPriorityGesture(TapGesture().onEnded {
                                self.model.camera = camera
                                dismiss()
                            })
                            VStack(alignment: .leading) {
                                Text(camera.name)
                                    .font(Constants.REGULAR_FONT_16)
                                Text("\(SensorFormat.allCases[camera.sensorFormat].name)")
                                    .font(Constants.REGULAR_FONT_14)
                            }
                        }
                    }
                    .listRowBackground(self.colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.9, green: 0.9, blue: 0.9))
                }
                .onDelete(perform: deleteCamera)
            }
            .scrollContentBackground(.hidden)
            .background(self.colorScheme == .dark ? .black : .white)
            .navigationDestination(for: Camera.self) { camera in
                CameraDetailView(camera: camera)
            }
            .foregroundStyle(self.colorScheme == .dark ? .white : .black)
            .alert("Camera In Use", isPresented: self.$cameraInUseAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This camera is used in one or more saved photo shoots. Remove it from those shoots before deleting it.")
            }
        }
        .sheet(isPresented: self.$addCameraViewVisible) {
            AddCameraView()
        }
    }
    
    private func deleteCamera(indexSet: IndexSet) {
        indexSet.forEach { index in
            let camera = cameras[index]

            let isInUse : Bool = self.photoShoots.contains { $0.camera.id == camera.id }
            guard !isInUse else {
                self.cameraInUseAlert = true
                return
            }

            context.delete(camera)
            do {
                try context.save()
            } catch {
                debugPrint(error.localizedDescription)
                context.rollback()
            }
        }
    }
}
