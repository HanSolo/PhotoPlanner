//
//  PhotoShootsView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 14.05.26.
//

import Foundation
import SwiftUI
import MapKit
import SwiftData


struct PhotoShootsView: View {
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(\.modelContext)         private var context
    @Environment(\.dismiss)              private var dismiss
    @Environment(PhotoPlannerModel.self) private var model
    
    let photoShoots : [PhotoShoot]

        
    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 10) {
                    
                    Text("Photo Shoots")
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                }
                .buttonStyle(.glass)
                .padding()
            }
            
            List {
                ForEach(photoShoots, id: \.id) { photoShoot in
                    NavigationLink(value: photoShoot) {
                        HStack(spacing: .some(15)) {
                            Button {
                            } label: {
                                Image(systemName: "photo.badge.checkmark.fill")
                            }
                            .highPriorityGesture(TapGesture().onEnded {
                                self.model.camera         = photoShoot.camera
                                self.model.lens           = photoShoot.lens
                                self.model.aperture       = photoShoot.aperture
                                self.model.focalLength    = photoShoot.focalLength
                                self.model.orientation    = photoShoot.isLandscape ? .landscape : .portrait
                                self.model.tc1.factor     = photoShoot.tc1
                                self.model.tc2.factor     = photoShoot.tc2
                                self.model.cameraDistance = photoShoot.cameraDistance
                                if self.model.cameraMarkerData  != nil { self.model.cameraMarkerData!.coordinate  = CLLocationCoordinate2D(latitude: photoShoot.cameraLat, longitude: photoShoot.cameraLon) }
                                if self.model.subjectMarkerData != nil { self.model.subjectMarkerData!.coordinate = CLLocationCoordinate2D(latitude: photoShoot.subjectLat, longitude: photoShoot.subjectLon) }
                                                     
                                
                                Properties.instance.cameraId         = photoShoot.camera.id
                                Properties.instance.lensId           = photoShoot.lens.id
                                Properties.instance.aperture         = photoShoot.aperture
                                Properties.instance.focalLength      = photoShoot.focalLength
                                Properties.instance.distance         = photoShoot.cameraDistance
                                Properties.instance.cameraLatitude   = photoShoot.cameraLat
                                Properties.instance.cameraLongitude  = photoShoot.cameraLon
                                Properties.instance.subjectLatitude  = photoShoot.subjectLat
                                Properties.instance.subjectLongitude = photoShoot.subjectLon
                                
                                self.model.updateFoVTriangle(cameraPoint: MKMapPoint(CLLocationCoordinate2D(latitude: photoShoot.cameraLat, longitude: photoShoot.cameraLon)), subjectPoint: MKMapPoint(CLLocationCoordinate2D(latitude: photoShoot.subjectLat, longitude: photoShoot.subjectLon)), focalLength: photoShoot.focalLength, aperture: photoShoot.aperture, sensorFormat: photoShoot.camera.sensorFormat, orientation: self.model.orientation, tc1: self.model.tc1, tc2: self.model.tc2)
                                self.model.triggerCenterToCamera.toggle() // Make sure the map will center to the new camera location
                                dismiss()
                            })
                            VStack(alignment: .leading) {
                                Text(photoShoot.name)
                                    .font(Constants.REGULAR_FONT_16)
                                Text(photoShoot.note!)
                                    .font(Constants.REGULAR_FONT_14)
                                Text("\(photoShoot.camera.name), \(photoShoot.lens.name)")
                                    .font(Constants.REGULAR_FONT_12)
                            }
                        }
                    }
                    .listRowBackground(self.colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.9, green: 0.9, blue: 0.9))
                }
                .onDelete(perform: deletePhotoShoot)
            }
            .scrollContentBackground(.hidden)
            .background(self.colorScheme == .dark ? .black : .white)
            /*
            .navigationDestination(for: PhotoShoot.self) { camera in
                CameraDetailView(camera: camera)
            }
            */
            .foregroundStyle(self.colorScheme == .dark ? .white : .black)
        }
    }
    
    private func deletePhotoShoot(indexSet: IndexSet) {
        indexSet.forEach { index in
            let photoShoot = photoShoots[index]
            context.delete(photoShoot)
            do {
                try context.save()
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}
