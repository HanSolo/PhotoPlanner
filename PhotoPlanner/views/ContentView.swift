//
//  ContentView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import SwiftUI
import MapKit


struct ContentView: View {
    let home                                  : CLLocationCoordinate2D = Constants.DEFAULT_LOCATION.coordinate
    @State private var position               : MapCameraPosition      = .automatic //.camera(.init(centerCoordinate: Constants.DEFAULT_LOCATION.coordinate, distance: 5000))
    @State private var cameraLocation         : CLLocationCoordinate2D = Constants.DEFAULT_LOCATION.coordinate
    @State private var modes                  : MapInteractionModes    = [.all]
    @State private var cameraMarkerActive     : Bool                   = false
    @State private var motifMarkerActive      : Bool                   = false
    @State private var isCameraMarkerDragging : Bool                   = false
    @State private var isMotifMarkerDragging  : Bool                   = false
    @State private var cameraMarkerData       : MarkerData?
    @State private var motifMarkerData        : MarkerData?
    
    
    var body: some View {
        ZStack (alignment: .topLeading) {
            GeometryReader { geo in
                MapReader { mapProxy in
                    Map(position: $position, interactionModes: [.all]) {
                        if let cameraMarkerData {
                            Annotation("", coordinate: cameraMarkerData.coordinate) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Image(systemName: "camera")
                                            .font(.system(size: 24))
                                            .padding(2)
                                            .foregroundStyle(self.cameraMarkerActive ? .blue : .white)
                                        Text("Camera")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                }
                            }
                        }
                        if let motifMarkerData {
                            Annotation("", coordinate: motifMarkerData.coordinate) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 24))
                                            .padding(2)
                                            .foregroundStyle(self.motifMarkerActive ? .blue : .white)
                                        Text("Motif")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                }
                            }
                        }
                    }
                    .onTapGestureBugFix { type, location  in
                        if nil != location {
                            if self.cameraMarkerActive {
                                self.cameraMarkerData = mapProxy.markerData(screenCoordinate: location!, geometryProxy: geo)
                            } else if self.motifMarkerActive {
                                self.motifMarkerData = mapProxy.markerData(screenCoordinate: location!, geometryProxy: geo)
                            }
                            
                        }
                    }
                    .highPriorityGesture(DragGesture(minimumDistance: 1)
                        .onChanged { drag in
                            if self.cameraMarkerActive {
                                guard let cameraMarkerData else { return }
                                if isCameraMarkerDragging {
                                    
                                } else if cameraMarkerData.touchArea.contains(drag.startLocation) {
                                    isCameraMarkerDragging = true
                                    setMapInteraction(enabled: false)
                                } else {
                                    return
                                }
                                self.cameraMarkerData = mapProxy.markerData(screenCoordinate: drag.location, geometryProxy: geo)
                            } else if self.motifMarkerActive {
                                guard let motifMarkerData else { return }
                                if isMotifMarkerDragging {
                                    
                                } else if motifMarkerData.touchArea.contains(drag.startLocation) {
                                    isMotifMarkerDragging = true
                                    setMapInteraction(enabled: false)
                                } else {
                                    return
                                }
                                self.motifMarkerData = mapProxy.markerData(screenCoordinate: drag.location, geometryProxy: geo)
                            }
                        }
                        .onEnded { drag in
                            setMapInteraction(enabled: true)
                            isCameraMarkerDragging = false
                            isMotifMarkerDragging  = false
                        }
                    )
                    .onMapCameraChange {
                        guard let cameraMarkerData else { return }
                        self.cameraMarkerData = mapProxy.markerData(coordinate: cameraMarkerData.coordinate, geometryProxy: geo)
                        
                        guard let motifMarkerData else { return }
                        self.motifMarkerData = mapProxy.markerData(coordinate: motifMarkerData.coordinate, geometryProxy: geo)
                    }
                    .mapControls {
                        MapScaleView()
                        MapCompass()
                        MapPitchToggle()
                        MapUserLocationButton()
                    }
                    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.beach, .castle, .fishing, .fortress, .hiking, .kayaking, .landmark, .marina, .nationalMonument, .nationalPark, .park, .rockClimbing, .skatePark, .surfing, .zoo]), showsTraffic: true))
                    .onAppear {
                        self.cameraMarkerData = MarkerData(coordinate: Constants.DEFAULT_LOCATION.coordinate, screenPoint: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                        self.motifMarkerData  = MarkerData(coordinate: Constants.DEFAULT_LOCATION.coordinate, screenPoint: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                    }
                }
            }
            VStack(alignment: .center, spacing: 10) {
                Toggle(isOn: $cameraMarkerActive) {
                    Image(systemName: "camera")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .onChange(of: self.cameraMarkerActive) { oldValue, newValue in
                    if newValue && self.motifMarkerActive { self.motifMarkerActive = false }
                }
                Toggle(isOn: $motifMarkerActive) {
                    Image(systemName: "photo")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .onChange(of: self.motifMarkerActive) { oldValue, newValue in
                    if newValue && self.cameraMarkerActive { self.cameraMarkerActive = false }
                }
            }
            .padding()
        }
    }
    
    private func setMapInteraction(enabled: Bool) {
        self.modes = enabled ? [.all] : []
    }
}

private extension MapProxy {

    func markerData(screenCoordinate: CGPoint, geometryProxy: GeometryProxy) -> MarkerData? {
        guard let coordinate = convert(screenCoordinate, from: .local) else { return nil }
        return .init(coordinate: coordinate, screenPoint: screenCoordinate)
    }

    func markerData(coordinate: CLLocationCoordinate2D, geometryProxy: GeometryProxy) -> MarkerData? {
        guard let point = convert(coordinate, to: .local) else { return nil }
        return .init(coordinate: coordinate, screenPoint: point)
    }
}
