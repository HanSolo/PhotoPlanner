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
    @State var showPopup : Bool = false

        
    var body: some View {
        ZStack {
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
                                Properties.instance.cameraId         = photoShoot.camera.id
                                Properties.instance.lensId           = photoShoot.lens.id
                                Properties.instance.aperture         = photoShoot.aperture
                                Properties.instance.focalLength      = photoShoot.focalLength
                                Properties.instance.distance         = photoShoot.cameraDistance
                                Properties.instance.cameraLatitude   = photoShoot.cameraLat
                                Properties.instance.cameraLongitude  = photoShoot.cameraLon
                                Properties.instance.subjectLatitude  = photoShoot.subjectLat
                                Properties.instance.subjectLongitude = photoShoot.subjectLon
                                
                                DispatchQueue.main.async {
                                    self.model.camera         = photoShoot.camera
                                    self.model.lens           = photoShoot.lens
                                    self.model.aperture       = photoShoot.aperture
                                    self.model.focalLength    = photoShoot.focalLength
                                    self.model.orientation    = photoShoot.isLandscape ? .landscape : .portrait
                                    self.model.tc1.factor     = photoShoot.tc1
                                    self.model.tc2.factor     = photoShoot.tc2
                                    self.model.cameraDistance = photoShoot.cameraDistance
                                }
                                
                                let cameraCoordinate  : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: photoShoot.cameraLat,  longitude: photoShoot.cameraLon)
                                let subjectCoordinate : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: photoShoot.subjectLat, longitude: photoShoot.subjectLon)
                                                                                           
                                self.model.cameraMarkerData  = MarkerData(coordinate: cameraCoordinate, screenPoint: CGPoint(x: 0, y: 0))
                                self.model.subjectMarkerData = MarkerData(coordinate: subjectCoordinate, screenPoint: CGPoint(x: 0, y: 0))
                                
                                self.model.updateFoVTriangle(cameraPoint: MKMapPoint(cameraCoordinate), subjectPoint: MKMapPoint(subjectCoordinate), focalLength: photoShoot.focalLength, aperture: photoShoot.aperture, sensorFormat: photoShoot.camera.sensorFormat, orientation: self.model.orientation, tc1: self.model.tc1, tc2: self.model.tc2)
                                
                                self.model.triggerCenterToCamera.toggle() // Make sure the map will center to the new camera location
                                                                                                                                                                
                                dismiss()
                            })
                                VStack(alignment: .leading, spacing: 2) {
                                Text(photoShoot.name)
                                    .font(Constants.REGULAR_FONT_16)
                                Text(photoShoot.note!)
                                    .font(Constants.REGULAR_FONT_14)
                                Text("\(photoShoot.camera.name), \(photoShoot.lens.name)")
                                    .font(Constants.REGULAR_FONT_12)
                                    HStack {
                                        let coordinates : String = "\(String(format: "%.7f", photoShoot.cameraLat)),\(String(format: "%.7f", photoShoot.cameraLon))"
                                        Text(coordinates)
                                            .font(Constants.REGULAR_FONT_12)
                                        Image(systemName: "document.on.document")
                                            .font(Constants.REGULAR_FONT_10)
                                            .onTapGesture {
                                                UIPasteboard.general.string = coordinates
                                                self.showPopup = true
                                            }
                                    }
                                    .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
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
            
            if showPopup {
                InfoPopup(showPopup: $showPopup)                                        
            }
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
