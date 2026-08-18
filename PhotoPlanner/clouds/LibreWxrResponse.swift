//
//  RainViewerResponse.swift
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
    }
    
    let host  : String
    let radar : Radar
}
