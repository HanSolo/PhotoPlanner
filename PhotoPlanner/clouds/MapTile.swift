//
//  MapTile.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 24.07.26.
//


import Foundation
import SwiftUI
import MapKit

struct MapTile {
    let x: Int
    let y: Int
    let z: Int

    // Converts a coordinate to the XYZ tile indices at a given zoom level
    static func tile(for coordinate: CLLocationCoordinate2D, zoom: Int) -> MapTile {
        let lat : Double = coordinate.latitude  * .pi / 180
        let n   : Double = pow(2.0, Double(zoom))
        let x   : Int    = Int((coordinate.longitude + 180.0) / 360.0 * n)
        let y   : Int    = Int((1.0 - log(tan(lat) + 1.0 / cos(lat)) / .pi) / 2.0 * n)
        return MapTile(x: x, y: y, z: zoom)
    }

    // OpenWeatherMap cloud tile URL
    func owmCloudURL(apiKey: String) -> URL? {
        return URL(string: "https://tile.openweathermap.org/map/clouds_new/\(z)/\(x)/\(y).png?appid=\(apiKey)")
    }

    // RainViwer tile URL
    func rainViewerURL(host: String, path: String) -> URL? {
        // host = "https://tilecache.rainviewer.com"
        // path = "/v2/radar/1609401600"
        // full tile URL = host + path + /256/z/x/y/2/1_1.png
        return URL(string: "\(host)\(path)/256/\(z)/\(x)/\(y)/2/1_1.png")
    }       
}

