//
//  DirectionalCloudInfo.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation


struct DirectionalCloudInfo {
    let sunAzimuth        : Double   // degrees clockwise from north
    let shootAzimuth      : Double   // camera pointing direction
    let angularDifference : Double   // absolute angular separation
    let shootingTowardSun : Bool     // within 45° of sun
    let shootingAwaySun   : Bool     // more than 135° from sun
}
