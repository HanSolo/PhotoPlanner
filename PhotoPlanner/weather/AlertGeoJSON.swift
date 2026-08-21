//
//  AlertGeoJSON.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.08.26.
//

import Foundation


struct AlertsGeoJSON: Decodable {
    struct Feature: Decodable {
        struct Properties: Decodable {
            let id       : String?
            let event    : String?
            let headline : String?
            let severity : String?
            let expiry   : String?
            let sender   : String?
        }
        let properties : Properties?
    }
    let features : [Feature]
}
