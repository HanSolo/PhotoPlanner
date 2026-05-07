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
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(PhotoPlannerModel.self) private var model
    
    let home                                  : CLLocationCoordinate2D = Constants.DEFAULT_LOCATION.coordinate
    @State private var position               : MapCameraPosition      = .camera(.init(centerCoordinate: CLLocationCoordinate2D(latitude: Properties.instance.cameraLatitude!, longitude: Properties.instance.cameraLongitude!), distance: 1500))
    @State private var modes                  : MapInteractionModes    = [.pan, .rotate, .zoom]
    @State private var cameraMarkerActive     : Bool                   = false
    @State private var motifMarkerActive      : Bool                   = false
    @State private var isPortrait             : Bool                   = false
    @State private var isCameraMarkerDragging : Bool                   = false
    @State private var isMotifMarkerDragging  : Bool                   = false
    @State private var mapStyle               : MapStyle               = .standard
    @State private var cameraViewVisible      : Bool                   = false
    @State private var lensViewVisible        : Bool                   = false
    @State private var datePickerVisible      : Bool                   = false
    @State private var helpViewVisible        : Bool                   = false
    @State private var centerCameraPosition   : Bool                   = false
    
    
    @Query(sort: [SortDescriptor(\Camera.name, comparator: .localizedStandard)]) private var cameras: [Camera]
    @Query(sort: [SortDescriptor(\Lens.name, comparator: .localizedStandard)])   private var lenses : [Lens]
    
    let lineWidth    : CGFloat = Constants.IS_IPAD ? 1.0 : 0.5
    let fovLineWidth : CGFloat = Constants.IS_IPAD ? 2.0 : 1.0
    
    
    var body: some View {
        ZStack (alignment: .topLeading) {
            GeometryReader { geo in
                MapReader { mapProxy in
                    Map(position: $position, interactionModes: [.pan, .rotate, .zoom]) {
                        if self.model.cameraMarkerData != nil {
                            Annotation("", coordinate: self.model.cameraMarkerData!.coordinate) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Image(systemName: "camera.circle")
                                            .font(.system(size: 24))
                                            .padding(2)
                                            .foregroundStyle(self.cameraMarkerActive ? .blue : (self.colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5)))
                                    }
                                }
                            }
                        }
                        if self.model.motifMarkerData != nil {
                            Annotation("", coordinate: self.model.motifMarkerData!.coordinate) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Image(systemName: "photo.circle")
                                            .font(.system(size: 24))
                                            .padding(2)
                                            .foregroundStyle(self.motifMarkerActive ? .blue : self.colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1))
                                    }
                                }
                            }
                        }                        
                        UserAnnotation()
                                                
                        if self.model.fovData != nil {
                            MapPolyline(points: [self.model.fovData!.cameraLocation, self.model.fovData!.motifLocation])
                                .stroke(Constants.CENTER_LINE_STROKE, lineWidth: lineWidth)
                        }
                        
                        if self.model.lens.isPrime { // Prime lens
                            MapPolygon(coordinates: self.model.triangleCoordinates)
                                .foregroundStyle(Color.clear)
                                .stroke(self.colorScheme == .dark ? Constants.FOV_STROKE_DARK : Constants.FOV_STROKE, lineWidth: fovLineWidth)
                        } else { // Zoom lens
                            MapPolygon(coordinates: self.model.triangleCoordinates)
                                .foregroundStyle(self.colorScheme == .dark ? Constants.FOV_FILL_DARK : Constants.FOV_FILL)
                                .stroke(self.colorScheme == .dark ? Constants.FOV_STROKE_DARK : Constants.FOV_STROKE, lineWidth: fovLineWidth)
                            MapPolygon(coordinates: self.model.minTriangleCoordinates)
                                .foregroundStyle(Color.clear)
                                .stroke(self.colorScheme == .dark ? Constants.FOV_STROKE_DARK : Constants.FOV_STROKE, lineWidth: lineWidth)                                            
                            MapPolygon(coordinates: self.model.maxTriangleCoordinates)
                                .foregroundStyle(Color.clear)
                                .stroke(self.colorScheme == .dark ? Constants.FOV_STROKE_DARK : Constants.FOV_STROKE, lineWidth: lineWidth)
                        }
                        if self.model.dofVisible {
                            MapPolygon(coordinates: self.model.trapezoidCoordinates)
                                .foregroundStyle(self.colorScheme == .dark ? Constants.DOF_FILL_DARK : Constants.DOF_FILL)
                                .stroke(self.colorScheme == .dark ? Constants.DOF_STROKE_DARK : Constants.DOF_STROKE, lineWidth: lineWidth)
                        }
                    }
                    .onTapGestureBugFix { type, location  in
                        if nil != location {
                            if self.cameraMarkerActive {
                                self.model.cameraMarkerData = mapProxy.markerData(screenCoordinate: location!, geometryProxy: geo)
                                Properties.instance.cameraLatitude  = self.model.cameraMarkerData!.coordinate.latitude
                                Properties.instance.cameraLongitude = self.model.cameraMarkerData!.coordinate.longitude
                            } else if self.motifMarkerActive {
                                self.model.motifMarkerData = mapProxy.markerData(screenCoordinate: location!, geometryProxy: geo)
                                Properties.instance.motifLatitude  = self.model.motifMarkerData!.coordinate.latitude
                                Properties.instance.motifLongitude = self.model.motifMarkerData!.coordinate.longitude
                            }
                            self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                            if self.model.dofVisible { self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation) }
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
                                if self.model.dofVisible { self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation) }
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
                                if self.model.dofVisible { self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation) }
                            }
                        }
                        .onEnded { drag in
                            setMapInteraction(enabled: true)
                            isCameraMarkerDragging = false
                            isMotifMarkerDragging  = false
                        }
                    )
                    .onMapCameraChange(frequency: .onEnd) { pos in
                        guard self.model.cameraMarkerData != nil else { return }
                        self.model.cameraMarkerData = mapProxy.markerData(coordinate: self.model.cameraMarkerData!.coordinate, geometryProxy: geo)
                        
                        guard self.model.motifMarkerData != nil else { return }
                        self.model.motifMarkerData    = mapProxy.markerData(coordinate: self.model.motifMarkerData!.coordinate, geometryProxy: geo)
                        self.model.currentMapLocation = pos.region.center
                        self.model.currentMapHeading  = pos.camera.heading
                    }
                    .mapControls {
                        MapScaleView()
                        MapCompass()
                    }
                    .mapStyle(self.mapStyle)
                    .onAppear {                        
                        self.model.checkIfLocationIsEnabled()
                    }
                }
            }
            
            OverlayView()
                .allowsHitTesting(false)
            
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: self.model.currentMapStyleIndexBinding) {
                    Text("Std").tag(0)
                        .font(Constants.REGULAR_FONT_14)
                    Text("Sat").tag(1)
                        .font(Constants.REGULAR_FONT_14)
                        .rotationEffect(Angle(degrees: 90))
                    Text("Hyb").tag(2)
                        .font(Constants.REGULAR_FONT_14)
                        .rotationEffect(Angle(degrees: 90))
                }
                .pickerStyle(.segmented)
                .onChange(of: self.model.currentMapStyleIndex) { oldValue, newValue in
                    switch newValue {
                    case  0: self.mapStyle = MapStyle.standard(elevation: .realistic, pointsOfInterest: .including([.beach, .castle, .fishing, .fortress, .hiking, .kayaking, .landmark, .marina, .nationalMonument, .nationalPark, .park, .rockClimbing, .skatePark, .surfing, .zoo]), showsTraffic: true)
                    case  1: self.mapStyle = MapStyle.imagery()
                    case  2: self.mapStyle = MapStyle.hybrid(elevation: .realistic, pointsOfInterest: .including([.beach, .castle, .fishing, .fortress, .hiking, .kayaking, .landmark, .marina, .nationalMonument, .nationalPark, .park, .rockClimbing, .skatePark, .surfing, .zoo]), showsTraffic: true)
                    default: self.mapStyle = MapStyle.standard(elevation: .realistic, pointsOfInterest: .including([.beach, .castle, .fishing, .fortress, .hiking, .kayaking, .landmark, .marina, .nationalMonument, .nationalPark, .park, .rockClimbing, .skatePark, .surfing, .zoo]), showsTraffic: true)
                    }
                }
                
                HStack {
                    Spacer()
                    
                    Text("\(self.model.camera.name) / \(self.model.lens.name)")
                        .font(Constants.REGULAR_FONT_14)
                        .foregroundStyle(self.colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                }
                .padding(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                .background(self.colorScheme == .dark ? .black.opacity(0.5) : .white.opacity(0.5))
                
                HStack {
                    Button {
                        self.cameraViewVisible = true
                    } label: {
                        Image(systemName: "camera")
                            .padding(7)
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    
                    Spacer()
                    
                    Toggle(isOn: $cameraMarkerActive) {
                        Image(systemName: "camera.circle")
                            .font(Constants.REGULAR_FONT_24)
                            .padding(7)
                    }
                    .frame(width: 44, height: 44)
                    .toggleStyle(.button)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    .onChange(of: self.cameraMarkerActive) { oldValue, newValue in
                        if newValue && self.motifMarkerActive { self.motifMarkerActive = false }
                    }
                }
                
                HStack {
                    Button {
                        self.lensViewVisible = true
                    } label: {
                        Image(systemName: "loupe")
                            .padding(7)
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    
                    Spacer()
                
                    Toggle(isOn: $motifMarkerActive) {
                        Image(systemName: "photo.circle")
                            .font(Constants.REGULAR_FONT_24)
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
                                      
                Toggle(isOn: self.model.dofVisibleBinding) {
                    Image(systemName: "trapezoid.and.line.vertical")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .onChange(of: self.model.dofVisible) { oldValue, newValue in
                    if newValue {
                        self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                    }
                }
                                                                                
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
                    if self.model.dofVisible { self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), motifPoint: MKMapPoint(self.model.motifMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation) }
                }
                
                Toggle(isOn: self.$datePickerVisible) {
                    Image(systemName: "calendar")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())    
                
                Toggle(isOn: self.model.epdVisibleBinding) {
                    Image(systemName: "sun.max")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())
                                                
                Button {
                    self.centerCameraPosition.toggle()
                } label: {
                    Image(systemName: "target")
                        .font(Constants.REGULAR_FONT_24)
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .onChange(of: self.centerCameraPosition) {
                    if self.model.cameraMarkerData != nil {
                        self.position = .camera(.init(centerCoordinate: self.model.cameraMarkerData!.coordinate, distance: 1500))
                    }
                }
                
                Spacer()
                
                Button {
                    self.helpViewVisible = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(Constants.REGULAR_FONT_24)
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 40, trailing: 0))
                
                HStack(alignment: .bottom, spacing: 5) {
                    VStack {
                        Slider(value: self.model.apertureBinding, in: self.model.lens.minAperture...self.model.lens.maxAperture)
                        Text("f/\(String(format: "%.1f", self.model.aperture))")
                            .font(Constants.REGULAR_FONT_14)
                    }
                                        
                    if self.model.dofVisible {
                        Spacer()
                        VStack(spacing: 10) {
                            Image.init(systemName: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill")
                                .rotationEffect(Angle(degrees: 90))
                                .font(Constants.REGULAR_FONT_14)
                            let dof       : Double = ((self.model.fovData?.dofInFront ?? 0.0) + (self.model.fovData?.dofBehind ?? 0.0))
                            let dofFormat : String = dof < 1 ? "%.2f m" : dof < 10 ? "%.1f m" : "%.0f m"
                            let dofText   : String = dof > 100 ? "∞" : String(format: dofFormat, dof)
                            Text(dofText)
                                .font(Constants.REGULAR_FONT_14)
                        }
                        Spacer()
                    } else {
                        Spacer()
                    }
                                            
                    
                    VStack {
                        Slider(value: self.model.focalLengthBinding, in: self.model.lens.minFocalLength...self.model.lens.maxFocalLength)
                            .disabled(self.model.lens.isPrime)
                        Text("\(String(format: "%.0f mm", self.model.focalLength))")
                            .font(Constants.REGULAR_FONT_14)
                    }
                }
                .padding(EdgeInsets(top: 5, leading: 5, bottom: 0, trailing: 5))
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            
            if self.helpViewVisible {
                HelpView()
                    .onTapGesture {
                        self.helpViewVisible = false
                    }
            }
        }
        .sheet(isPresented: $cameraViewVisible) {
            CameraView(cameras: self.cameras)
        }
        .sheet(isPresented: $lensViewVisible) {
            LensView(lenses: self.lenses)
        }
        .sheet(isPresented: $datePickerVisible) {
            DateTimeView()
        }
        .task {
            let savedCameraId        : String     = Properties.instance.cameraId        ?? Constants.DEFAULT_CAMERA.id
            let savedLensId          : String     = Properties.instance.lensId          ?? Constants.DEFAULT_LENS.id
            let savedAperture        : Double     = Properties.instance.aperture        ?? 2.8
            let savedFocalLength     : Double     = Properties.instance.focalLength     ?? 24
            let savedCameraLatitude  : Double     = Properties.instance.cameraLatitude  ?? Constants.DEFAULT_LOCATION.coordinate.latitude
            let savedCameraLongitude : Double     = Properties.instance.cameraLongitude ?? Constants.DEFAULT_LOCATION.coordinate.longitude
            let savedMotifLatitude   : Double     = Properties.instance.motifLatitude   ?? Constants.DEFAULT_LOCATION.coordinate.latitude
            let savedMotifLongitude  : Double     = Properties.instance.motifLongitude  ?? Constants.DEFAULT_LOCATION.coordinate.longitude
            let cameraPoint          : MKMapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: savedCameraLatitude, longitude: savedCameraLongitude))
            let motifPoint           : MKMapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: savedMotifLatitude, longitude: savedMotifLongitude))
            
            self.model.camera         = cameras.filter({ $0.id == savedCameraId }).first ?? Constants.DEFAULT_CAMERA
            self.model.lens           = lenses.filter({ $0.id == savedLensId }).first ?? Constants.DEFAULT_LENS
            self.model.aperture       = savedAperture
            self.model.focalLength    = savedFocalLength
                                    
            self.model.cameraMarkerData = MarkerData(coordinate: cameraPoint.coordinate, screenPoint: CGPoint(x: 0, y: 0))
            self.model.motifMarkerData  = MarkerData(coordinate: motifPoint.coordinate, screenPoint: CGPoint(x: 0, y: 0))
            self.model.updateFoVTriangle(cameraPoint: cameraPoint, motifPoint: motifPoint, focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
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
