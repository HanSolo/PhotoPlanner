//
//  ISSPositionResponse.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.09.26.
//


// Decodes a single wheretheiss.at satellite response.
struct ISSPositionResponse: Decodable {
    let latitude  : Double
    let longitude : Double
    let timestamp : Double
}
