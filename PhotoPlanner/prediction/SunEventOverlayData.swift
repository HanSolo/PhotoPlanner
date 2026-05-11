//
//  SunEventOverlayData.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation


struct SunEventOverlayData {
    let event       : SolarEvent
    let score       : SunriseSunsetScore
    let directional : DirectionalCloudInfo
    let shootTime   : Date
}
