//
//  OpenMeteoResponse.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.08.26.
//
import Foundation


struct OpenMeteoResponse: Decodable, Sendable {
    struct Hourly: Decodable {
        let time               : [String]
        let wind_speed_10m     : [Double?]
        let wind_direction_10m : [Double?]
    }
    let hourly : Hourly
}
