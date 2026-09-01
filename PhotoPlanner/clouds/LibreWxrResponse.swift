//
//  LibreWxrResponse.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 14.08.26.
//

import Foundation


struct LibreWxrResponse: Decodable {

    struct Radar: Decodable {
        struct Frame: Decodable {
            let time : Int
            let path : String
        }
        let past : [Frame]
        let nowcast : [Frame]
    }

    struct Satellite: Decodable {
        struct Frame: Decodable {
            let time : Int
            let path : String
        }
        let infrared : [Frame]
    }

    let host      : String
    let radar     : Radar
    let satellite : Satellite?
}
