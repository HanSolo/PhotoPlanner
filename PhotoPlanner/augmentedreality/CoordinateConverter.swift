//
//  CoordinateConverter.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


struct CoordinateConverter {

    /// Converts azimuth and altitude to a unit direction vector
    /// in ARKit's right-handed coordinate system where: +X = right, +Y = up, -Z = forward (into screen)
    /// The azimuth is measured clockwise from north (before north offset is applied).
    nonisolated static func directionVector(azimuthDegrees:  Double, altitudeDegrees: Double) -> SCNVector3 {
        let azimuthRad  : Double = azimuthDegrees  * .pi / 180
        let altitudeRad : Double = altitudeDegrees * .pi / 180

        let x           : Float  = Float( cos(altitudeRad) * sin(azimuthRad))
        let y           : Float  = Float( sin(altitudeRad))
        let z           : Float  = Float(-cos(altitudeRad) * cos(azimuthRad))

        return SCNVector3(x, y, z)
    }

    /// Rotates a direction vector around the Y axis by the given offset.
    /// Used to align ARKit's coordinate frame with true north.
    nonisolated static func applyNorthOffset(to vector: SCNVector3, offsetRadians: Float) -> SCNVector3 {
        let cosOffset : Float = cos(offsetRadians)
        let sinOffset : Float = sin(offsetRadians)
        return SCNVector3(x: vector.x * cosOffset + vector.z * sinOffset, y: vector.y, z: -vector.x * sinOffset + vector.z * cosOffset)
    }

    /// Projects a world-space direction vector to a position on a sphere of the given radius, centred at the origin.
    nonisolated static func spherePosition(direction: SCNVector3, radius: Float = 10.0) -> SCNVector3 {
        let length : Float = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        guard length > 0 else { return SCNVector3(0, 0, -radius) }
        return SCNVector3(direction.x / length * radius, direction.y / length * radius, direction.z / length * radius)
    }
}
