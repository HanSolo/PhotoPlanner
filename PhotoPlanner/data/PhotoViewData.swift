//
//  PhotoViewData.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public struct PhotoViewData: Codable {
    let name          : String?
    let description   : String?
    let cameraLat     : String?
    let cameraLon     : String?
    let motifLat      : String?
    let motifLon      : String?
    let cameraName    : String?
    let sensorFormat  : String?
    let lensName      : String?
    let minFocalLength: String?
    let maxFocalLength: String?
    let minAperture   : String?
    let maxAperture   : String?
    let focalLength   : String?
    let aperture      : String?
    let orientation   : String?
    let countryCode   : String?
    let originLat     : String?
    let originLon     : String?
    let mapWidth      : String?
    let mapHeight     : String?
    let tags          : String?
    let equipment     : String?
    let times         : String?
    
    
    init(name: String, description: String, cameraLat: String, cameraLon: String, motifLat: String, motifLon: String, cameraName: String, sensorFormat: String,
         lensName: String, minFocalLength: String, maxFocalLength: String, minAperture: String, maxAperture: String,
         focalLength: String, aperture: String, orientation: String, countryCode: String, originLat: String, originLon: String, mapWidth: String, mapHeight: String, tags: String, equipment: String, times: String) {
        self.name           = name
        self.description    = description
        self.cameraLat      = cameraLat
        self.cameraLon      = cameraLon
        self.motifLat       = motifLat
        self.motifLon       = motifLon
        self.cameraName     = cameraName
        self.sensorFormat   = sensorFormat
        self.lensName       = lensName
        self.minFocalLength = minFocalLength
        self.maxFocalLength = maxFocalLength
        self.minAperture    = minAperture
        self.maxAperture    = maxAperture
        self.focalLength    = focalLength
        self.aperture       = aperture
        self.orientation    = orientation
        self.countryCode    = countryCode
        self.originLat      = originLat
        self.originLon      = originLon
        self.mapWidth       = mapWidth
        self.mapHeight      = mapHeight
        self.tags           = tags
        self.equipment      = equipment
        self.times          = times
    }
    init(dictionary: Dictionary<String, String>) throws {
        self = try JSONDecoder().decode(PhotoViewData.self, from: JSONSerialization.data(withJSONObject: dictionary))
    }
}
