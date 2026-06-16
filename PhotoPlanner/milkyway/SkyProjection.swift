//
//  SkyProjection.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 16.06.26.
//

import Foundation
import SwiftUI


public struct SkyProjection {
    let maxRadius : CGFloat
    let center    : CGPoint

    // altitude 90° → centre, altitude 0° → maxRadius, altitude < 0° → nil
    func calcScreenPoint(altitude: Double, azimuth: Double) -> CGPoint? {
        guard altitude >= 0 else { return nil }
        let projectedRadius : CGFloat = CGFloat(1.0 - min(90.0, altitude) / 90.0) * maxRadius
        let angleRad        : CGFloat = CGFloat((azimuth - 90.0) * .pi / 180.0)
        return CGPoint(x: center.x + projectedRadius * cos(angleRad), y: center.y + projectedRadius * sin(angleRad))
    }

    func calcHorizonPoint(azimuth: Double) -> CGPoint {
        let angleRad : CGFloat = CGFloat((azimuth - 90.0) * .pi / 180.0)
        return CGPoint(x: center.x + maxRadius * cos(angleRad), y: center.y + maxRadius * sin(angleRad))
    }
    
    func isOnScreen(point: CGPoint, screenSize: CGSize, margin: CGFloat = 20) -> Bool {
        return point.x >= -margin && point.x <= screenSize.width  + margin && point.y >= -margin && point.y <= screenSize.height + margin
    }
}
