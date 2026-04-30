//
//  Constants.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import MapKit
import SwiftUI


public class Constants {
    public static let APP_NAME                : String = "PhotoPlanner"
    public static let APP_GROUP_ID            : String = "group.eu.hansolo.PhotoPlanner"
    public static let CONTAINER_ID            : String = "iCloud.eu.hansolo.PhotoPlannerContainer"
    
    public static let EARTH_RADIUS            : Double = 6_378_137.0 // in m
    public static let DATE_FORMAT             : String = "HH:mm"
    public static let EPD_SUN                 : String = "sun"
    public static let EPD_MOON                : String = "moon"
    public static let EPD_BLUE_HOUR_MORNING   : String = "blueHourMorning"
    public static let EPD_GOLDEN_HOUR_MORNING : String = "goldenHourMorning"
    public static let EPD_SUNRISE             : String = "sunrise"
    public static let EPD_GOLDEN_HOUR_EVENING : String = "goldenHourEvening"
    public static let EPD_SUNSET              : String = "sunset"
    public static let EPD_BLUE_HOUR_EVENING   : String = "blueHourEvening"
    public static let EPD_MOONRISE            : String = "moonrise"
    public static let EPD_MOONSET             : String = "moonset"
    public static let EPD_GOLDEN_HOUR_END     : String = "goldenHourEnd"
    public static let EPD_GOLDEN_HOUR         : String = "goldenHour"
    public static let EPD_SUNRISE_END         : String = "sunriseEnd"
    public static let EPD_SUNSET_START        : String = "sunsetStart"
    public static let EPD_BLUE_HOUR_DAWN_END  : String = "blueHourDawnEnd"
    public static let EPD_BLUE_HOUR_DUSK      : String = "blueHourDusk"
    public static let EPD_DAWN                : String = "dawn"
    public static let EPD_DUSK                : String = "dusk"
    public static let EPD_BLUE_HOUR_DAWN      : String = "blueHourDawn"
    public static let EPD_BLUE_HOUR_DUSK_END  : String = "blueHourDuskEnd"
    public static let EPD_NAUTICAL_DAWN       : String = "nauticalDawn"
    public static let EPD_NAUTICAL_DUSK       : String = "nauticalDusk"
    public static let EPD_NIGHT_END           : String = "nightEnd"
    public static let EPD_NIGHT               : String = "night"
    public static let EPD_RISE                : String = "rise"
    public static let EPD_SET                 : String = "set"
    public static let EPD_AZIMUTH             : String = "azimuth"
    public static let EPD_ALTITUDE            : String = "altitude"
    public static let EPD_ALWAYS_UP           : String = "alwaysUp"
    public static let EPD_ALWAYS_DOWN         : String = "alwaysDown"
    public static let EPD_SOLAR_NOON          : String = "solarNoon"
    public static let EPD_NADIR               : String = "nadir"
    public static let EPD_DEC                 : String = "dec"
    public static let EPD_RA                  : String = "ra"
    public static let EPD_DIST                : String = "dist"
    public static let EPD_FRACTION            : String = "fraction"
    public static let EPD_PHASE               : String = "phase"
    public static let EPD_ANGLE               : String = "angle"
    
    public static let FOV_COLOR           : Color = Color(red: 0.0, green: 0.56078431, blue: 0.8627451)
    public static let FOV_FILL            : Color = FOV_COLOR.opacity(0.3)
    public static let FOV_STROKE          : Color = Color.white
    public static let DOF_COLOR           : Color = Color.pink
    public static let DOF_FILL            : Color = DOF_COLOR.opacity(0.1)
    public static let DOF_STROKE          : Color = DOF_COLOR
    public static let CENTER_LINE_STROKE  : Color = Color.white
    
    public static let MOON_RISE_STROKE    : Color = Color(red: 0.0,  green: 0.9,        blue:  0.9)
    public static let MOON_SET_STROKE     : Color = Color(red: 0.0,  green: 0.375,      blue:  0.75)
    public static let MOON_STROKE         : Color = Color(red: 0.0,  green: 0.5,        blue:  0.5)
    public static let SUN_RISE_STROKE     : Color = Color(red: 0.9,  green: 0.9,        blue:  0.0)
    public static let SUN_SET_STROKE      : Color = Color(red: 0.75, green: 0.375,      blue:  0.0)
    public static let SUN_STROKE          : Color = Color(red: 0.5,  green: 0.5,        blue:  0.0)
    
    public static let DEFAULT_LOCATION    : MKMapPoint = MKMapPoint(CLLocationManager().location?.coordinate ?? CLLocationCoordinate2D(latitude : 51.911821, longitude: 7.633703))
    public static let DEFAULT_CAMERA      : Camera = Camera(name        : "DEFAULT CAMERA", sensorFormat: SensorFormat.fullFormat.id)
    public static let DEFAULT_LENS        : Lens   = Lens(name          : "DEFAULT LENS",
                                                          minFocalLength: 24,
                                                          maxFocalLength: 70,
                                                          minAperture   : 2.8,
                                                          maxAperture   : 22,
                                                          sensorFormat  : SensorFormat.fullFormat.id)
    
    public static let DEFAULT_ORIENTATION : CameraOrientation = CameraOrientation.landscape
    public static let DEFAULT_MAP_SIZE    : MKMapSize   = MKMapSize(width: 97313.02098080516, height: 60438.11837643385)
    public static let DEFAULT_ORIGIN      : MKMapPoint  = MKMapPoint(x: DEFAULT_LOCATION.x - DEFAULT_MAP_SIZE.width / 2, y: DEFAULT_LOCATION.y - DEFAULT_MAP_SIZE.height / 2)
                        
    public static let REGULAR_FONT_14     : Font    = Font.system(size: 14, weight: .regular, design: .rounded)
    public static let REGULAR_FONT_16     : Font    = Font.system(size: 16, weight: .regular, design: .rounded)
    public static let REGULAR_FONT_20     : Font    = Font.system(size: 20, weight: .regular, design: .rounded)
    public static let REGULAR_FONT_24     : Font    = Font.system(size: 24, weight: .regular, design: .rounded)
    public static let REGULAR_FONT_28     : Font    = Font.system(size: 28, weight: .regular, design: .rounded)
}
