//
//  MapTile.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 24.07.26.
//


import Foundation
import CoreLocation


public struct MapTile {
    let x : Int
    let y : Int
    let z : Int

    // Converts a coordinate to the XYZ tile indices at a given zoom level
    nonisolated static func tile(for coordinate: CLLocationCoordinate2D, zoom: Int) -> MapTile {
        let lat : Double = coordinate.latitude  * .pi / 180
        let n   : Double = pow(2.0, Double(zoom))
        let x   : Int    = Int((coordinate.longitude + 180.0) / 360.0 * n)
        let y   : Int    = Int((1.0 - log(tan(lat) + 1.0 / cos(lat)) / .pi) / 2.0 * n)
        return MapTile(x: x, y: y, z: zoom)
    }

    // OpenWeatherMap cloud tile URL
    nonisolated func owmCloudURL(apiKey: String) -> URL? {
        return URL(string: "https://tile.openweathermap.org/map/clouds_new/\(z)/\(x)/\(y).png?appid=\(apiKey)")
    }

    /** LibreWXR tile URL
     ** ColorSchemes:
     **   0 -> Black and White
     **   1 -> Rainviewer Original
     **   2 -> Universal Blue
     **   3 -> Titan
     **   4 -> The Weather Channel
     **   5 -> Meteored
     **   6 -> NEXRAD Level III
     **   7 -> Rainbow
     **   8 -> Dark Sky
     **   9 -> Datameteo Valerio
     ** 10 -> Viper HD
     ** 11 -> MRMS CREF
     ** 12 -> 33/40 Max Storm
     ** 13 ->
     ** 14 -> Windy
     **/
    nonisolated func libreWxrURL(host: String, path: String, colorScheme: Int = 14, tileSize: Int = 256) -> URL? {
        // host  = "https://hansolo.eu"
        // path  = "/v2/radar/1609401600"
        // color = /256/z/x/y/COLOR_SCHEME/SMOOTH_SNOW.png
        // smooth = 0 = false / 1 = true
        // snow   = 0 = false / 1 = true
        // full tile URL = host + path + /256/z/x/y/2/1_1.png
        return URL(string: "\(host)\(path)/\(tileSize)/\(z)/\(x)/\(y)/\(colorScheme)/1_1.png")
    }

    // LibreWXR satellite tile URL
    nonisolated func libreWxrSatelliteURL(host: String, path: String) -> URL? {
        return URL(string: "\(host)\(path)/256/\(z)/\(x)/\(y)/0/0_0.png")
    }
}
