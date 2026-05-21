//
//  ARSceneBuilder.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine

class ARSceneBuilder {

    // Sphere radius for celestial objects — large enough to always be visible
    static let celestialSphereRadius: Float = 10.0

    // Builds a line node representing the sun's arc across the sky for the given day.
    // Coloured by time: blue hour = blue, golden hour = orange, daytime = yellow.
    static func buildSunArcNode(coordinate: CLLocationCoordinate2D, date: Date, northOffsetRadians: Float, stepMinutes: Int = 5) -> SCNNode {
        let containerNode    : SCNNode  = SCNNode()
        let calendar         : Calendar = Calendar.current
        let startOfDay       : Date     = calendar.startOfDay(for: date)
        var previousPosition : SCNVector3?

        for minutes in stride(from: 0.0, through: 1440, by: Double(stepMinutes)) {
            let sampleTime : Date   = startOfDay.addingTimeInterval(minutes * 60)
            let sunPos     : SunPos = Helper.calcSunPos(at: coordinate, time: sampleTime)

            // Only draw arc above civil twilight
            guard sunPos.altitude > -6 else {
                previousPosition = nil
                continue
            }

            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: sunPos.azimuth, altitudeDegrees: sunPos.altitude)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            
            let position  : SCNVector3 = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius)

            if let previous : SCNVector3 = previousPosition {
                let segmentColor : UIColor = sunArcColor(altitude: sunPos.altitude)
                let segment      : SCNNode = buildLineSegment(from: previous, to: position, color: segmentColor, radius: 0.030)
                containerNode.addChildNode(segment)
            }
            previousPosition = position
        }
        return containerNode
    }

    private static func sunArcColor(altitude: Double) -> UIColor {
        switch altitude {
            case -6..<0 :  return UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.9)   // blue hour
            case 0..<6  :  return UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 0.95)  // golden hour
            case 6..<12 :  return UIColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 0.85) // warm light
            default     :  return UIColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 0.7)  // daytime
        }
    }

    
    static func buildMoonArcNode(coordinate: CLLocationCoordinate2D, date: Date, northOffsetRadians: Float, stepMinutes: Int = 10) -> SCNNode {
        let containerNode    : SCNNode  = SCNNode()
        let calendar         : Calendar = Calendar.current
        let startOfDay       : Date     = calendar.startOfDay(for: date)
        var previousPosition : SCNVector3?

        
        for minutes in stride(from: 0.0, through: 1440, by: Double(stepMinutes)) {
            let sampleTime          : Date             = startOfDay.addingTimeInterval(minutes * 60)
            let (altitude, azimuth) : (Double, Double) = MoonCalculator.calcMoonPosition(at: coordinate, time: sampleTime)

            guard altitude > 0 else {
                previousPosition = nil
                continue
            }

            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: azimuth, altitudeDegrees: altitude)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            
            let position : SCNVector3  = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius)

            if let previous : SCNVector3 = previousPosition {
                let segment : SCNNode = buildLineSegment(from: previous, to: position, color: UIColor(white: 0.85, alpha: 0.6), radius: 0.025)
                containerNode.addChildNode(segment)
            }
            previousPosition = position
        }
        return containerNode
    }

    
    static func buildSunIndicatorNode() -> SCNNode {
        let sphere : SCNSphere = SCNSphere(radius: 0.32) // 0.12
        sphere.firstMaterial?.diffuse.contents  = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        sphere.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.7,  blue: 0.0, alpha: 0.8)
        sphere.firstMaterial?.lightingModel     = .constant

        let node   : SCNNode   = SCNNode(geometry: sphere)

        // Glow halo
        let halo   : SCNSphere = SCNSphere(radius: 0.20)
        halo.firstMaterial?.diffuse.contents  = UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 0.15)
        halo.firstMaterial?.lightingModel     = .constant
        halo.firstMaterial?.isDoubleSided     = true
        node.addChildNode(SCNNode(geometry: halo))

        return node
    }

    
    static func buildMoonIndicatorNode(illumination: Double) -> SCNNode {
        let sphere     : SCNSphere = SCNSphere(radius: 0.24) // 0.08
        let brightness : Float     = Float(0.4 + illumination * 0.5)
        sphere.firstMaterial?.diffuse.contents  = UIColor(white: CGFloat(brightness), alpha: 1.0)
        sphere.firstMaterial?.emission.contents = UIColor(white: CGFloat(brightness * 0.3), alpha: 1.0)
        sphere.firstMaterial?.lightingModel     = .constant
        return SCNNode(geometry: sphere)
    }

    
    static func buildCardinalMarkersNode(northOffsetRadians: Float) -> SCNNode {
        let containerNode : SCNNode            = SCNNode()
        let cardinals     : [(String, Double)] = [("N", 0), ("E", 90), ("S", 180), ("W", 270)]

        for (label, azimuth) in cardinals {
            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: azimuth, altitudeDegrees: 0)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            
            let position  : SCNVector3 = CoordinateConverter.spherePosition(
                direction: direction, radius: celestialSphereRadius * 0.95
            )

            let textGeometry : SCNText = SCNText(string: label, extrusionDepth: 0.01)
            textGeometry.font                            = UIFont.systemFont(ofSize: 0.3, weight: .bold)
            textGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
            textGeometry.firstMaterial?.lightingModel    = .constant

            let textNode     : SCNNode = SCNNode(geometry: textGeometry)
            textNode.position = position

            // Billboard constraint so text always faces camera
            let billboardConstraint : SCNBillboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .all
            textNode.constraints         = [billboardConstraint]

            // Centre the text geometry
            let (min, max) : (SCNVector3, SCNVector3) = textGeometry.boundingBox
            textNode.pivot = SCNMatrix4MakeTranslation((max.x - min.x) / 2, (max.y - min.y) / 2, 0)
            
            containerNode.addChildNode(textNode)
        }
        return containerNode
    }

    
    static func buildHorizonRingNode(northOffsetRadians: Float) -> SCNNode {
        let containerNode    : SCNNode = SCNNode()
        let segmentCount     : Int     = 72   // every 5 degrees
        var previousPosition : SCNVector3?

        for step in 0...segmentCount {
            let azimuth   : Double     = Double(step) / Double(segmentCount) * 360.0
            
            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: azimuth, altitudeDegrees: 0)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            
            let position  : SCNVector3 = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius)

            if let previous : SCNVector3 = previousPosition {
                let segment = buildLineSegment(from: previous, to: position, color: UIColor.white.withAlphaComponent(0.15), radius: 0.005)
                containerNode.addChildNode(segment)
            }
            previousPosition = position
        }
        return containerNode
    }
    
    
    static func buildLineSegment(from start: SCNVector3, to end: SCNVector3, color: UIColor, radius: CGFloat) -> SCNNode {
        let deltaX   : Float       = end.x - start.x
        let deltaY   : Float       = end.y - start.y
        let deltaZ   : Float       = end.z - start.z
        let length   : Float       = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)

        let cylinder : SCNCylinder = SCNCylinder(radius: radius, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.lightingModel    = .constant

        let node     : SCNNode     = SCNNode(geometry: cylinder)
        node.position = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)        

        // Orient cylinder to point from start to end
        let up      : SCNVector3 = SCNVector3(0, 1, 0)
        let forward : SCNVector3 = SCNVector3(deltaX / length, deltaY / length, deltaZ / length)
        let cross   : SCNVector3 = SCNVector3(up.y * forward.z - up.z * forward.y, up.z * forward.x - up.x * forward.z, up.x * forward.y - up.y * forward.x)
        let dot     : Float      = up.x * forward.x + up.y * forward.y + up.z * forward.z
        let angle   : Float      = acos(max(-1, min(1, dot)))

        if simd_length(simd_float3(cross.x, cross.y, cross.z)) > 0.001 {
            node.rotation = SCNVector4(cross.x, cross.y, cross.z, angle)
        }

        return node
    }
}
