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
        
    let home                                    : CLLocationCoordinate2D = Constants.DEFAULT_LOCATION.coordinate
    @State private var sunQualityViewModel      : SunQualityViewModel    = SunQualityViewModel()
    @State private var milkywayViewModel        : MilkywayViewModel      = MilkywayViewModel()
    @State private var moonViewModel            : MoonViewModel          = MoonViewModel()
    @State private var position                 : MapCameraPosition      = .camera(.init(centerCoordinate: CLLocationCoordinate2D(latitude: Properties.instance.cameraLatitude!, longitude: Properties.instance.cameraLongitude!), distance: Properties.instance.distance!))
    @State private var modes                    : MapInteractionModes    = [.pan, .rotate, .zoom]
    @State private var cameraMarkerActive       : Bool                   = false
    @State private var subjectMarkerActive      : Bool                   = false
    @State private var isPortrait               : Bool                   = !Properties.instance.landscape!
    @State private var isCameraMarkerDragging   : Bool                   = false
    @State private var isSubjectMarkerDragging  : Bool                   = false
    @State private var mapStyle                 : MapStyle               = .standard
    @State private var cameraViewVisible        : Bool                   = false
    @State private var lensViewVisible          : Bool                   = false
    @State private var teleconverterViewVisible : Bool                   = false
    @State private var datePickerVisible        : Bool                   = false
    @State private var sunsetPredictionVisible  : Bool                   = false
    @State private var moonPhaseVisible         : Bool                   = false
    @State private var milkywayVisible          : Bool                   = false
    @State private var helpViewVisible          : Bool                   = false
    @State private var elevationViewVisible     : Bool                   = false
    @State private var centerCameraPosition     : Bool                   = false
        
    @Query(sort: [SortDescriptor(\Camera.name, comparator: .localizedStandard)]) private var cameras: [Camera]
    @Query(sort: [SortDescriptor(\Lens.name, comparator: .localizedStandard)])   private var lenses : [Lens]
    
    let lineWidth    : CGFloat = Constants.IS_IPAD ? 1.0 : 0.5
    let fovLineWidth : CGFloat = Constants.IS_IPAD ? 2.0 : 1.0
    
    init() {
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(red: 0.25, green: 0.56, blue: 0.96, alpha: 1.00)
        UISegmentedControl.appearance().backgroundColor          = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
    }
    
    
    var body: some View {
        ZStack (alignment: .topLeading) {
            // MapView
            GeometryReader { geo in
                MapReader { mapProxy in
                    Map(position: $position, interactionModes: [.pan, .rotate, .zoom]) {
                        if self.model.cameraMarkerData != nil {
                            Annotation("", coordinate: self.model.cameraMarkerData!.coordinate) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Image(self.cameraMarkerActive ? "cameraPinActive" : "cameraPin")
                                            .resizable()
                                            .frame(width: 48, height: 48)
                                            .offset(y: -24)
                                    }
                                }
                            }
                        }
                        if self.model.subjectMarkerData != nil {
                            Annotation("", coordinate: self.model.subjectMarkerData!.coordinate) {
                                ZStack(alignment: .center) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Image(self.subjectMarkerActive ? "subjectPinActive" : "subjectPin")
                                            .resizable()
                                            .frame(width: 48, height: 48)
                                            .offset(y: -24)
                                            .opacity(self.subjectMarkerActive ? 1.0 : 0.1)
                                    }
                                }
                            }
                        }                        
                        UserAnnotation()
                                                
                        if self.model.fovData != nil {
                            MapPolyline(points: [self.model.fovData!.cameraLocation, self.model.fovData!.subjectLocation])
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
                                if self.elevationViewVisible { self.elevationViewVisible = false }
                            } else if self.subjectMarkerActive {
                                self.model.subjectMarkerData = mapProxy.markerData(screenCoordinate: location!, geometryProxy: geo)
                                Properties.instance.subjectLatitude  = self.model.subjectMarkerData!.coordinate.latitude
                                Properties.instance.subjectLongitude = self.model.subjectMarkerData!.coordinate.longitude
                                if self.elevationViewVisible { self.elevationViewVisible = false }
                            }
                            self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation, tc1: self.model.tc1, tc2: self.model.tc2)
                            if self.model.dofVisible { self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation) }
                        }
                    }
                    .highPriorityGesture(DragGesture(minimumDistance: 1)
                        .onChanged { drag in
                            if self.cameraMarkerActive {
                                guard self.model.cameraMarkerData != nil else { return }
                                if isCameraMarkerDragging {
                                    if self.elevationViewVisible { self.elevationViewVisible = false }
                                } else if self.model.cameraMarkerData!.touchArea.contains(drag.startLocation) {
                                    isCameraMarkerDragging = true
                                    setMapInteraction(enabled: false)
                                } else {
                                    return
                                }
                                self.model.cameraMarkerData = mapProxy.markerData(screenCoordinate: drag.location, geometryProxy: geo)
                                self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation, tc1: self.model.tc1, tc2: self.model.tc2)
                                if self.model.dofVisible { self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation) }
                            } else if self.subjectMarkerActive {
                                guard self.model.subjectMarkerData != nil else { return }
                                if isSubjectMarkerDragging {
                                    if self.elevationViewVisible { self.elevationViewVisible = false }
                                } else if self.model.subjectMarkerData!.touchArea.contains(drag.startLocation) {
                                    isSubjectMarkerDragging = true
                                    setMapInteraction(enabled: false)
                                } else {
                                    return
                                }
                                self.model.subjectMarkerData = mapProxy.markerData(screenCoordinate: drag.location, geometryProxy: geo)
                                self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation, tc1: self.model.tc1, tc2: self.model.tc2)
                                if self.model.dofVisible { self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation) }
                            }
                        }
                        .onEnded { drag in
                            setMapInteraction(enabled: true)
                            isCameraMarkerDragging = false
                            isSubjectMarkerDragging  = false
                        }
                    )
                    .onMapCameraChange(frequency: .onEnd) { pos in
                        guard self.model.cameraMarkerData != nil else { return }
                        self.model.cameraMarkerData = mapProxy.markerData(coordinate: self.model.cameraMarkerData!.coordinate, geometryProxy: geo)
                        
                        guard self.model.subjectMarkerData != nil else { return }
                        self.model.subjectMarkerData    = mapProxy.markerData(coordinate: self.model.subjectMarkerData!.coordinate, geometryProxy: geo)
                        self.model.currentMapLocation = pos.region.center
                        self.model.currentMapHeading  = pos.camera.heading
                        Properties.instance.distance  = pos.camera.distance
                    }
                    .mapControls {
                        MapScaleView()
                        MapCompass()
                    }
                    .mapStyle(self.mapStyle)
                    /*
                    .overlay {
                        Rectangle()
                            .fill(.white.opacity(0.25))
                            .blendMode(.saturation)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                    */
                    .onAppear {
                        self.model.checkIfLocationIsEnabled()
                    }
                }
            }
            
            // OverlayView
            OverlayView()
                .allowsHitTesting(false)
            
            // ElevationView
            if self.elevationViewVisible {
                ElevationProfileView(profile: self.model.elevationProfile)
                    .allowsTightening(false)
            }
                        
            // Controls
            VStack(alignment: .leading, spacing: 10) {
                HStack {
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
                    
                    Button {
                        self.helpViewVisible = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .padding(7)
                    }
                    .frame(width: 22, height: 22)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
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
                        Image("cameraPin")
                            .resizable()
                            .frame(width: 32, height: 32)
                    }
                    .frame(width: 44, height: 44)
                    .toggleStyle(.button)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    .onChange(of: self.cameraMarkerActive) { oldValue, newValue in
                        if newValue && self.subjectMarkerActive { self.subjectMarkerActive = false }
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
                    
                    Toggle(isOn: $subjectMarkerActive) {
                        Image("subjectPin")
                            .resizable()
                            .frame(width: 32, height: 32)
                    }
                    .frame(width: 44, height: 44)
                    .toggleStyle(.button)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    .onChange(of: self.subjectMarkerActive) { oldValue, newValue in
                        if newValue && self.cameraMarkerActive { self.cameraMarkerActive = false }
                    }
                }
                
                HStack {
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
                            self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation)
                        }
                    }
                    
                    Spacer()
                    
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
                            self.position = .camera(.init(centerCoordinate: self.model.cameraMarkerData!.coordinate, distance: self.model.cameraDistance))
                        }
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
                    self.model.updateFoVTriangle(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation, tc1: self.model.tc1, tc2: self.model.tc2)
                    if self.model.dofVisible { self.model.updateDoFTrapezoid(cameraPoint: MKMapPoint(self.model.cameraMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), subjectPoint: MKMapPoint(self.model.subjectMarkerData?.coordinate ?? Constants.DEFAULT_LOCATION.coordinate), focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation) }
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
                
                Toggle(isOn: self.$sunsetPredictionVisible) {
                    Image(systemName: "sunset")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .onChange(of: self.sunsetPredictionVisible) {
                    if self.sunsetPredictionVisible {
                        if self.model.cameraMarkerData != nil {
                            let now          : Date                   = Date()
                            let location     : CLLocationCoordinate2D = self.model.cameraMarkerData!.coordinate
                            let shootAzimuth : Double                 = Helper.calcAzimuth(location1: self.model.cameraMarkerData!.coordinate, location2: self.model.subjectMarkerData!.coordinate)
                            let sunPos       : SunPos                 = Helper.calcSunPos(at: location, time: now)
                            var solarEvent   : SolarEvent {
                                SolarEvent(time: now, type: .sunset)
                            }
                            Task {
                                await self.sunQualityViewModel.fetch(at: location, on: now, shootAzimuth: shootAzimuth, sunPos: sunPos)
                            }
                        }
                    }
                }
                                
                Toggle(isOn: self.$moonPhaseVisible) {
                    Image(systemName: "moon")
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .onChange(of: self.moonPhaseVisible) {
                    if self.model.cameraMarkerData != nil {
                        Task {
                            let location : CLLocationCoordinate2D = self.model.cameraMarkerData!.coordinate
                            let date     : Date                   = self.model.currentMapDate
                            let timeZone : TimeZone               = await Helper.fetchTimeZone(for: location)
                            self.moonViewModel.fetch(at: location, time: date, timeZone: timeZone)
                        }
                    }
                }
                
                Toggle(isOn: self.$milkywayVisible) {
                    Image(systemName: "star.circle")
                        .font(Constants.REGULAR_FONT_24)
                        .padding(7)
                }
                .frame(width: 44, height: 44)
                .toggleStyle(.button)
                .buttonStyle(.glass)
                .clipShape(Circle())
                .onChange(of: self.milkywayVisible) {
                    if self.model.cameraMarkerData != nil {
                        let location : CLLocationCoordinate2D = self.model.cameraMarkerData!.coordinate
                        let date     : Date                   = self.model.currentMapDate
                        Task {
                            await self.milkywayViewModel.fetch(at: location, on: date)
                        }
                    }
                }

                HStack {
                    Toggle(isOn: self.$elevationViewVisible) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .padding(10)
                    }
                    .frame(width: 44, height: 44)
                    .toggleStyle(.button)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                    .disabled(!self.model.networkMonitor.isConnected || self.model.fovData?.distance ?? 0 >= 4000)
                    .onChange(of: self.elevationViewVisible) {
                        if self.elevationViewVisible {
                            Task {
                                await self.model.getElevation()
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        self.teleconverterViewVisible = true
                    } label: {
                        Image(systemName: "t.circle")
                            .font(Constants.REGULAR_FONT_24)
                            .padding(7)
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                }
                
                Spacer()
                
                // Aperture Slider
                HStack(alignment: .bottom, spacing: 5) {
                    VStack {
                        Slider(value: self.model.apertureBinding, in: self.model.minAperture...self.model.maxAperture)
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
                                            
                    // Focal Length Slider
                    VStack {
                        Slider(value: self.model.focalLengthBinding, in: self.model.minFocalLength...self.model.maxFocalLength)
                            .disabled(self.model.lens.isPrime)
                        Text("\(String(format: "%.0f mm", self.model.focalLength))")
                            .font(Constants.REGULAR_FONT_14)
                    }
                }
                .padding(EdgeInsets(top: 5, leading: 5, bottom: 0, trailing: 5))
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
                   
            if self.sunsetPredictionVisible {
                SunQualityMapOverlay(vm: sunQualityViewModel)
            }
            
            if self.moonPhaseVisible {
                MoonPhaseMapOverlay(vm: moonViewModel)
            }
            
            if self.milkywayVisible {
                MilkywayMapOverlay(vm: milkywayViewModel)
            }
            
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
        .sheet(isPresented: $teleconverterViewVisible) {
            TeleconverterView()
        }
        .task {
            let savedCameraId         : String     = Properties.instance.cameraId         ?? Constants.DEFAULT_CAMERA.id
            let savedLensId           : String     = Properties.instance.lensId           ?? Constants.DEFAULT_LENS.id
            let savedAperture         : Double     = Properties.instance.aperture         ?? 2.8
            let savedFocalLength      : Double     = Properties.instance.focalLength      ?? 24
            let savedDistance         : Double     = Properties.instance.distance         ?? 1500
            let savedCameraLatitude   : Double     = Properties.instance.cameraLatitude   ?? Constants.DEFAULT_LOCATION.coordinate.latitude
            let savedCameraLongitude  : Double     = Properties.instance.cameraLongitude  ?? Constants.DEFAULT_LOCATION.coordinate.longitude
            let savedSubjectLatitude  : Double     = Properties.instance.subjectLatitude  ?? Constants.DEFAULT_LOCATION.coordinate.latitude
            let savedSubjectLongitude : Double     = Properties.instance.subjectLongitude ?? Constants.DEFAULT_LOCATION.coordinate.longitude
            let cameraPoint           : MKMapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: savedCameraLatitude, longitude: savedCameraLongitude))
            let subjectPoint          : MKMapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: savedSubjectLatitude, longitude: savedSubjectLongitude))
            
            self.model.camera         = cameras.filter({ $0.id == savedCameraId }).first  ?? Constants.DEFAULT_CAMERA
            self.model.lens           = lenses.filter({ $0.id == savedLensId }).first     ?? Constants.DEFAULT_LENS
            self.model.aperture       = savedAperture
            self.model.focalLength    = savedFocalLength
            self.model.cameraDistance = savedDistance
                                    
            self.model.cameraMarkerData = MarkerData(coordinate: cameraPoint.coordinate, screenPoint: CGPoint(x: 0, y: 0))
            self.model.subjectMarkerData  = MarkerData(coordinate: subjectPoint.coordinate, screenPoint: CGPoint(x: 0, y: 0))
            self.model.updateFoVTriangle(cameraPoint: cameraPoint, subjectPoint: subjectPoint, focalLength: self.model.focalLength, aperture: self.model.aperture, sensorFormat: self.model.camera.sensorFormat, orientation: self.model.orientation, tc1: self.model.tc1, tc2: self.model.tc2)
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
