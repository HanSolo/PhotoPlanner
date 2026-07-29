//
//  Address.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.07.26.
//

import Foundation
import CoreLocation
import MapKit


public struct Address {
    let name        : String
    let zip         : String
    let city        : String
    let subCity     : String
    let street      : String
    let subStreet   : String
    let state       : String
    let subState    : String
    let country     : String
    let isoCode     : String
    let inlandWater : String
    let ocean       : String
    let timezone    : TimeZone
    let isDst       : Bool
    let dstOffset   : Double
    let latitude    : Double
    let longitude   : Double
    
    
    init(mapItem: MKMapItem) {
        let coord = mapItem.location.coordinate
        let rep   = mapItem.addressRepresentations
        self.init(name     : mapItem.name ?? "",
                  city     : rep?.cityName ?? "",
                  country  : rep?.regionName ?? "",
                  isoCode  : rep?.region?.identifier ?? "",
                  timezone : mapItem.timeZone ?? TimeZone.current,
                  latitude : coord.latitude,
                  longitude: coord.longitude)
    }
    init(name: String = "", zip: String = "", city: String = "", subCity: String = "", street: String = "", subStreet: String = "", state: String = "", subState: String = "", country: String = "", isoCode: String = "", inlandWater: String = "", ocean: String = "", timezone: TimeZone = TimeZone.current, latitude: Double = 0.0, longitude: Double = 0.0) {
        let now : Date = Date.init()
        
        self.name        = name
        self.zip         = zip
        self.city        = city
        self.subCity     = subCity
        self.street      = street
        self.subStreet   = subStreet
        self.state       = state
        self.subState    = subState
        self.country     = country
        self.isoCode     = isoCode
        self.inlandWater = inlandWater
        self.ocean       = ocean
        self.timezone    = timezone
        self.isDst       = timezone.isDaylightSavingTime(for: now)
        self.dstOffset   = Double(timezone.daylightSavingTimeOffset(for: now).rounded() / 3600.0)
        self.latitude    = latitude
        self.longitude   = longitude
    }
    
    public func location() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
    public func formatted() -> String {
        var txt : String = "\(self.name.isEmpty ? "" : self.name)"
        txt += txt.isEmpty ? "" : "\n"
        
        if !self.inlandWater.isEmpty || !self.ocean.isEmpty {
            txt += "\(self.inlandWater.isEmpty ? self.ocean : self.inlandWater)\n"
        } else {
            if !self.city.isEmpty {
                txt += "\(self.zip.isEmpty ? "" : self.zip) \(self.city)\n"
            }
            if self.name.isEmpty && !self.street.isEmpty {
                txt += "\(self.street)\n"
            }
            if !self.state.isEmpty {
                txt += "\(self.state)\n"
            }
            if !self.country.isEmpty {
                txt += "\(self.country)\(self.isoCode.isEmpty ? "" : " (\(self.isoCode))\n")"
            }
        }
        let timezoneOffsetInHours   : Double = Double(self.timezone.secondsFromGMT()) / 3600.0
        txt += "GMT \(timezoneOffsetInHours > 0 ? "+" : "")\(String(format: "%.1f", timezoneOffsetInHours))\n"
        if self.isDst {
            txt += "Daylight saving ˜\(self.dstOffset > 0 ? "+" : "")\(String(format: "%.1f", self.dstOffset))"
        }
        txt += "\(String(format: "%.10f", self.latitude)),\(String(format: "%.10f", self.longitude))"
        
        return txt
    }
        
    public func toString() -> String {
        var txt : String = "";
        txt += "name       : \(self.name)\n"
        txt += "zip        : \(self.zip)\n"
        txt += "city       : \(self.city)\n"
        txt += "subCity    : \(self.subCity)\n"
        txt += "street     : \(self.street)\n"
        txt += "subStreet  : \(self.subStreet)\n"
        txt += "state      : \(self.state)\n"
        txt += "subState   : \(self.subState)\n"
        txt += "country    : \(self.country)\n"
        txt += "isoCode    : \(self.isoCode)\n"
        txt += "inlandWater: \(self.inlandWater)\n"
        txt += "ocean      : \(self.ocean)\n"
        txt += "timezone   : \(self.timezone)\n"
        txt += "latitude   : \(self.latitude)\n"
        txt += "longitude  : \(self.longitude)"
        return txt
    }
    
}
