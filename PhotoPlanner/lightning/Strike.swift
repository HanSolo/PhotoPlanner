//
//  Strike.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 17.08.26.
//

import Foundation


class Strike: Codable {
    var region : Int?
    var lat    : Double?
    var latc   : Int?
    var alt    : Int?
    var mcg    : Int?
    var sig    : [Sig]?
    var status : Int?
    var time   : Int64?
    var delay  : Double?
    var pol    : Int?
    var mds    : Int?
    var lon    : Double?
    var lonc   : Int?

    private enum CodingKeys: String, CodingKey {
        case region = "region"
        case lat    = "lat"
        case latc   = "latc"
        case alt    = "alt"
        case mcg    = "mcg"
        case sig    = "sig"
        case status = "status"
        case time   = "time"
        case delay  = "delay"
        case pol    = "pol"
        case mds    = "mds"
        case lon    = "lon"
        case lonc   = "lonc"
    }

    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        region = try? container.decode(Int.self,    forKey: .region)
        lat    = try? container.decode(Double.self, forKey: .lat)
        latc   = try? container.decode(Int.self,    forKey: .latc)
        alt    = try? container.decode(Int.self,    forKey: .alt)
        mcg    = try? container.decode(Int.self,    forKey: .mcg)
        sig    = try? container.decode([Sig].self,  forKey: .sig)
        status = try? container.decode(Int.self,    forKey: .status)
        time   = try? container.decode(Int64.self,  forKey: .time)
        delay  = try? container.decode(Double.self, forKey: .delay)
        pol    = try? container.decode(Int.self,    forKey: .pol)
        mds    = try? container.decode(Int.self,    forKey: .mds)
        lon    = try? container.decode(Double.self, forKey: .lon)
        lonc   = try? container.decode(Int.self,    forKey: .lonc)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(region, forKey: .region)
        try? container.encode(lat,    forKey: .lat)
        try? container.encode(latc,   forKey: .latc)
        try? container.encode(alt,    forKey: .alt)
        try? container.encode(mcg,    forKey: .mcg)
        try? container.encode(sig,    forKey: .sig)
        try? container.encode(status, forKey: .status)
        try? container.encode(time,   forKey: .time)
        try? container.encode(delay,  forKey: .delay)
        try? container.encode(pol,    forKey: .pol)
        try? container.encode(mds,    forKey: .mds)
        try? container.encode(lon,    forKey: .lon)
        try? container.encode(lonc,   forKey: .lonc)
    }
}

class Sig: Codable {
    var status : Int?
    var lat    : Double?
    var alt    : Int?
    var lon    : Double?
    var sta    : Int?
    var time   : Int?

    private enum CodingKeys: String, CodingKey {
        case status = "status"
        case lat    = "lat"
        case alt    = "alt"
        case lon    = "lon"
        case sta    = "sta"
        case time   = "time"
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try? container.decode(Int.self,    forKey: .status)
        lat    = try? container.decode(Double.self, forKey: .lat)
        alt    = try? container.decode(Int.self,    forKey: .alt)
        lon    = try? container.decode(Double.self, forKey: .lon)
        sta    = try? container.decode(Int.self,    forKey: .sta)
        time   = try? container.decode(Int.self,    forKey: .time)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(status, forKey: .status)
        try? container.encode(lat,    forKey: .lat)
        try? container.encode(alt,    forKey: .alt)
        try? container.encode(lon,    forKey: .lon)
        try? container.encode(sta,    forKey: .sta)
        try? container.encode(time,   forKey: .time)
    }
}
