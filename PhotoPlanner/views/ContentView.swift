//
//  ContentView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import SwiftUI
import SwiftData
import MapKit


struct ContentView: View {
    @Environment(PhotoPlannerModel.self) private var model
    
    let home                                  : CLLocationCoordinate2D = Constants.DEFAULT_LOCATION.coordinate
    @State private var position               : MapCameraPosition      = .automatic //.camera(.init(centerCoordinate: Constants.DEFAULT_LOCATION.coordinate, distance: 5000))
    @State private var cameraLocation         : CLLocationCoordinate2D = Constants.DEFAULT_LOCATION.coordinate
    @State private var modes                  : MapInteractionModes    = [.pan, .rotate, .zoom]
    @State private var cameraMarkerActive     : Bool                   = false
    @State private var motifMarkerActive      : Bool                   = false
    @State private var isPortrait             : Bool                   = false
    @State private var isCameraMarkerDragging : Bool                   = false
    @State private var isMotifMarkerDragging  : Bool                   = false
    
    @State private var lensViewVisible        : Bool                   = false
    
    
    @Query(sort: [SortDescriptor(\Lens.name, comparator: .localizedStandard)]) private var lenses: [Lens]
    
    
    var body: some View {
        ZStack (alignment: .topLeading) {
            GeometryReader { geo in
                MapReader { mapProxy in
                    Map(position: $position, interactionModes: [.pan, .rotate, .zoom]) {
                        if self.model.cameraMarkerData != nil {
                            Annotation("", coordinate: self.model.cameraMarkerData!.coordinate) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Image(systemName: "camera")
                                            .font(.system(size: 24))
                                            .padding(2)
                                            .foregroundStyle(self.cameraMarkerActive ? .blue : .white.opacity(0.5))
                                        Text("Camera")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                }
                            }
                        }
                        if self.model.motifMarkerData != nil {
                            Annotation("", coordinate: self.model.motifMarkerData!.coordinate) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 24))
                                            .padding(2)
                                            .foregroundStyle(self.motifMarkerActive ? .blue : .white.opacity(0.5))
                                        Text("Motif")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                }
                            }
                        }
                                                
                        if self.model.fovData != nil {
                            MapPolyline(points: [self.model.fovData!.cameraLocation, self.model.fovData!.motifLocation])
                                .stroke(.blue, lineWidth: 0.5)
                        }
                        
                        if self.model.lens.isPrime { // Prime lens
                            MapPolygon(coordinates: self.model.triangleCoordinates)
                                .foregroundStyle(Color.clear)
                                .stroke(Color.blue, lineWidth: 0.5)
                        } else { // Zoom lens
                            MapPolygon(coordinates: self.model.triangleCoordinates)
                                .foregroundStyle(Color.blue.opacity(0.2))
                                .stroke(Color.blue, lineWidth: 0.5)
                            MapPolygon(coordinates: self.model.minTriangleCoordinates)
                                .foregroundStyle(Color.clear)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 0.5)
                            
                            MapPolygon(coordinates: self.model.maxTriangleCoordinates)
                                .foregroundStyle(Color.clear)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 0.5)
                        }
                                                                                            
                        MapPolygon(coordinates: self.model.trapezoidCoordinates)
                            .foregroundStyle(Color.green.opacity(0.2))
                            .stroke(Color.green, lineWidth: 0.5)
                    }
                    .onTapGestureBugFix { type, location  in
                        if nil != location {
                            if self.cameraMarkerActive {
                                self.model.cameraMarkerData = mapProxy.markerData(screenCoordinate: location!, geometryProxy: geo)
                            } else if self.motifMarkerActive {
                                self.model.motifMarkerData = mapProxy.markerData(screenCoordinate: location!, geometryProxy: geo)
                            }
                            self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                            self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                        }
                    }
                    .highPriorityGesture(DragGesture(minimumDistance: 1)
                        .onChanged { drag in
                            if self.cameraMarkerActive {
                                guard self.model.cameraMarkerData != nil else { return }
                                if isCameraMarkerDragging {
                                    
                                } else if self.model.cameraMarkerData!.touchArea.contains(drag.startLocation) {
                                    isCameraMarkerDragging = true
                                    setMapInteraction(enabled: false)
                                } else {
                                    return
                                }
                                self.model.cameraMarkerData = mapProxy.markerData(screenCoordinate: drag.location, geometryProxy: geo)
                                self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                                self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                            } else if self.motifMarkerActive {
                                guard self.model.motifMarkerData != nil else { return }
                                if isMotifMarkerDragging {
                                    
                                } else if self.model.motifMarkerData!.touchArea.contains(drag.startLocation) {
                                    isMotifMarkerDragging = true
                                    setMapInteraction(enabled: false)
                                } else {
                                    return
                                }
                                self.model.motifMarkerData = mapProxy.markerData(screenCoordinate: drag.location, geometryProxy: geo)
                                self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                                self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                            }
                        }
                        .onEnded { drag in
                            setMapInteraction(enabled: true)
                            isCameraMarkerDragging = false
                            isMotifMarkerDragging  = false
                        }
                    )
                    .onMapCameraChange {
                        guard self.model.cameraMarkerData != nil else { return }
                        self.model.cameraMarkerData = mapProxy.markerData(coordinate: self.model.cameraMarkerData!.coordinate, geometryProxy: geo)
                        
                        guard self.model.motifMarkerData != nil else { return }
                        self.model.motifMarkerData = mapProxy.markerData(coordinate: self.model.motifMarkerData!.coordinate, geometryProxy: geo)
                    }
                    .mapControls {
                        MapScaleView()
                        MapCompass()
                        MapUserLocationButton()
                    }
                    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.beach, .castle, .fishing, .fortress, .hiking, .kayaking, .landmark, .marina, .nationalMonument, .nationalPark, .park, .rockClimbing, .skatePark, .surfing, .zoo]), showsTraffic: true))
                    .onAppear {
                        self.model.cameraMarkerData = MarkerData(coordinate: Constants.DEFAULT_LOCATION.coordinate, screenPoint: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                        self.model.motifMarkerData  = MarkerData(coordinate: Constants.DEFAULT_LOCATION.coordinate, screenPoint: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
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
                
                Button {
                    self.lensViewVisible = true
                } label: {
                    Image(systemName: "loupe")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .buttonStyle(.glass)
                .clipShape(Circle())
                
                Toggle(isOn: $isPortrait) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera")
                        .padding(7)
                        .rotationEffect(self.isPortrait ? .degrees(-90) : .zero)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .onChange(of: self.isPortrait) { oldValue, newValue in
                    self.model.orientation = newValue ? .portrait : .landscape
                    self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                    self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                }
                
                Spacer()
                
                HStack {
                    VStack {
                        Slider(value: self.model.apertureBinding, in: self.model.lens.minAperture...self.model.lens.maxAperture)
                        Text("f/\(String(format: "%.1f", self.model.aperture))")
                            .font(Constants.REGULAR_FONT_14)
                    }
                    
                    Spacer()
                    VStack {
                        Slider(value: self.model.focalLengthBinding, in: self.model.lens.minFocalLength...self.model.lens.maxFocalLength)
                            .disabled(self.model.lens.isPrime)
                        Text("\(String(format: "%.0f", self.model.focalLength)) mm")
                            .font(Constants.REGULAR_FONT_14)
                    }
                    
                }
            }
            .padding()
        }
        .sheet(isPresented: $lensViewVisible) {
            LensView(lenses: self.lenses)
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
