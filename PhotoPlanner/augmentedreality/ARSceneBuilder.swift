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


struct ArcPoint {
    let position : SCNVector3
    let color    : UIColor
}

struct HourLabelPoint {
    let position : SCNVector3
    let color    : UIColor
    let hour     : Int
    let fontSize : CGFloat
}


struct ARSceneBuilder {

    nonisolated static let celestialSphereRadius: Float = 10.0
    
    nonisolated static func computeSunArcPoints(coordinate: CLLocationCoordinate2D, date: Date, northOffsetRadians: Float, timeZone: TimeZone = .current, stepMinutes: Int = 8) -> [ArcPoint] {
        var points            : [ArcPoint] = []
        var calendar          : Calendar   = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay        : Date       = calendar.startOfDay(for: date)
        var previousPosition  : SCNVector3?

        for minutes in stride(from: 0.0, through: 1440, by: Double(stepMinutes)) {
            let sampleTime : Date        = startOfDay.addingTimeInterval(minutes * 60)
            let sunPos     : SunPosition = SolarCalculator.calcSunPosition(at: coordinate, time: sampleTime)

            guard sunPos.altitude > -6 else {
                previousPosition = nil
                continue
            }

            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: sunPos.azimuth, altitudeDegrees: sunPos.altitude)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            let position  : SCNVector3 = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius)

            if previousPosition != nil {
                points.append(ArcPoint(position: position, color: sunArcColor(altitude: sunPos.altitude)))
            }
            previousPosition = position
        }
        return points
    }

    
    nonisolated static func computeMoonArcPoints(coordinate: CLLocationCoordinate2D, date: Date, northOffsetRadians: Float, timeZone: TimeZone = .current, stepMinutes: Int = 15) -> [ArcPoint] {
        var points            : [ArcPoint] = []
        var calendar          : Calendar   = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay        : Date       = calendar.startOfDay(for: date)
        var previousPosition  : SCNVector3?

        for minutes in stride(from: 0.0, through: 1440, by: Double(stepMinutes)) {
            let sampleTime          : Date             = startOfDay.addingTimeInterval(minutes * 60)
            let (altitude, azimuth) : (Double, Double) = MoonCalculator.calcMoonPosition(at: coordinate, time: sampleTime)

            guard altitude > 0 else {
                previousPosition = nil
                continue
            }

            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: azimuth, altitudeDegrees: altitude)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            let position  : SCNVector3 = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius)

            if previousPosition != nil {
                points.append(ArcPoint(position: position,color: UIColor(white: 0.85, alpha: 0.6)))
            }
            previousPosition = position
        }
        return points
    }

    
    nonisolated static func computeSunHourLabelPoints(coordinate: CLLocationCoordinate2D, date: Date, northOffsetRadians: Float, timeZone: TimeZone = .current) -> [HourLabelPoint] {
        var points        : [HourLabelPoint] = [HourLabelPoint]()
        var calendar      : Calendar         = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        
        let startOfDay    : Date             = calendar.startOfDay(for: date)
                
        for hour in 0..<24 {
            let sampleTime : Date        = startOfDay.addingTimeInterval(Double(hour) * 3600)
            let sunPos     : SunPosition = SolarCalculator.calcSunPosition(at: coordinate, time: sampleTime)

            guard sunPos.altitude > -6 else { continue }
            
            let localHour : Int        = calendar.component(.hour, from: sampleTime)

            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: sunPos.azimuth, altitudeDegrees: sunPos.altitude)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            
            let position  : SCNVector3 = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius + 0.35)

            points.append(HourLabelPoint(position: position, color:sunLabelColor(altitude: sunPos.altitude), hour: localHour, fontSize: 0.36))
        }
        
        return points
    }

    
    nonisolated static func computeMoonHourLabelPoints(coordinate: CLLocationCoordinate2D, date: Date, northOffsetRadians: Float, timeZone: TimeZone = .current) -> [HourLabelPoint] {
        var points        : [HourLabelPoint] = [HourLabelPoint]()
        var calendar      : Calendar         = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfDay    : Date             = calendar.startOfDay(for: date)

        for hour in 0..<24 {
            let sampleTime          : Date             = startOfDay.addingTimeInterval(Double(hour) * 3600)
            let (altitude, azimuth) : (Double, Double) = MoonCalculator.calcMoonPosition(at: coordinate, time: sampleTime)

            guard altitude > 0 else { continue }

            let localHour : Int        = calendar.component(.hour, from: sampleTime)
            
            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: azimuth, altitudeDegrees: altitude)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            
            let position  : SCNVector3 = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius + 0.35)

            points.append(HourLabelPoint(position: position, color: UIColor(white: 0.9, alpha: 0.75), hour: localHour, fontSize: 0.36))
        }
        return points
    }

    
    nonisolated static func computeCardinalPoints(northOffsetRadians: Float) -> [(position: SCNVector3, label: String)] {
        let cardinals: [(String, Double)] = [ ("N", 0), ("E", 90), ("S", 180), ("W", 270) ]
        
        return cardinals.map { label, azimuth in
            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: azimuth, altitudeDegrees: 0)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            let position  : SCNVector3 = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius * 0.95)
            return (position, label)
        }
    }

    nonisolated static func computeHorizonRingPoints(northOffsetRadians: Float, segmentCount: Int = 72) -> [ArcPoint] {
        var points : [ArcPoint] = [ArcPoint]()

        for step in 0...segmentCount {
            let azimuth   : Double     = Double(step) / Double(segmentCount) * 360.0
            var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: azimuth, altitudeDegrees: 0)
            direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
            let position  : SCNVector3 = CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius)
            points.append(ArcPoint(position: position, color: UIColor.white.withAlphaComponent(0.15)))
        }
        return points
    }

    
    nonisolated static func computeSunIndicatorPosition(coordinate: CLLocationCoordinate2D, time: Date, northOffsetRadians: Float) -> (position: SCNVector3, altitude: Double)? {
        let sunPos : SunPosition = SolarCalculator.calcSunPosition(at: coordinate, time: time)
        guard sunPos.altitude > -6 else { return nil }

        var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: sunPos.azimuth, altitudeDegrees: sunPos.altitude)
        direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
        return (CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius), sunPos.altitude)
    }

    
    nonisolated static func computeMoonIndicatorPosition(coordinate: CLLocationCoordinate2D, time: Date, northOffsetRadians: Float) -> (position: SCNVector3, illumination: Double)? {
        let (altitude, azimuth) : (Double, Double) = MoonCalculator.calcMoonPosition(at: coordinate, time: time)
        guard altitude > 0 else { return nil }

        let moonPhase : MoonPhase  = MoonCalculator.calcMoonPhase(at: coordinate, time: time, timeZone: TimeZone.current)

        var direction : SCNVector3 = CoordinateConverter.directionVector(azimuthDegrees: azimuth, altitudeDegrees: altitude)
        direction = CoordinateConverter.applyNorthOffset(to: direction, offsetRadians: northOffsetRadians)
        return (CoordinateConverter.spherePosition(direction: direction, radius: celestialSphereRadius), moonPhase.illumination)
    }

    
    @MainActor
    static func buildArcNode(from points: [ArcPoint], lineRadius: CGFloat) -> SCNNode {
        let containerNode : SCNNode = SCNNode()

        for (index, point) in points.enumerated().dropFirst() {
            let previous = points[index - 1]
            let segment  = buildLineSegment(from: previous.position, to: point.position, color: point.color, radius: lineRadius)
            containerNode.addChildNode(segment)
        }
        return containerNode
    }

    
    @MainActor
    static func buildHourLabelsNode(from points: [HourLabelPoint]) -> SCNNode {
        let containerNode : SCNNode = SCNNode()

        for point in points {
            let labelNode = buildHourLabelNode(hour: point.hour, position: point.position, color: point.color, fontSize: point.fontSize)
            containerNode.addChildNode(labelNode)
        }
        return containerNode
    }

        
    @MainActor
    static func buildCardinalMarkersNode(from points: [(position: SCNVector3, label: String)]) -> SCNNode {
        let containerNode : SCNNode = SCNNode()

        for (position, label) in points {
            let liftedPosition : SCNVector3 = SCNVector3(position.x, position.y + 1.2, position.z)

            let markerNode : SCNNode = SCNNode()
            markerNode.position = liftedPosition

            let billboard : SCNBillboardConstraint = SCNBillboardConstraint()
            billboard.freeAxes     = .all
            markerNode.constraints = [billboard]

            let image       : UIImage  = renderCardinalImage(label: label)
            let aspectRatio : Float    = Float(image.size.width / image.size.height)
            let planeHeight : Float    = 1.0
            let plane       : SCNPlane = SCNPlane(width: CGFloat(planeHeight * aspectRatio), height: CGFloat(planeHeight))
            plane.firstMaterial?.diffuse.contents    = image
            plane.firstMaterial?.lightingModel       = .constant
            plane.firstMaterial?.isDoubleSided       = true
            plane.firstMaterial?.transparencyMode    = .aOne
            plane.firstMaterial?.writesToDepthBuffer = false

            let planeNode : SCNNode = SCNNode(geometry: plane)
            markerNode.addChildNode(planeNode)
            containerNode.addChildNode(markerNode)
        }

        return containerNode
    }

    private static func renderCardinalImage(label: String) -> UIImage {
        let size     : CGSize                  = CGSize(width: 256, height: 256)
        let renderer : UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cgContext : CGContext = ctx.cgContext

            cgContext.setFillColor(UIColor.black.withAlphaComponent(0.65).cgColor)
            cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))

            cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
            cgContext.setLineWidth(4)
            cgContext.strokeEllipse(in: CGRect(x: 3, y: 3, width: size.width  - 6, height: size.height - 6))

            let font       : UIFont                        = UIFont.systemFont(ofSize: 110, weight: .heavy)  // was 52
            let attributes : [NSAttributedString.Key: Any] = [ .font: font, .foregroundColor: UIColor.white]
            let textSize   : CGSize                        = (label as NSString).size(withAttributes: attributes)
            let textOrigin : CGPoint                       = CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2)
            (label as NSString).draw(at: textOrigin, withAttributes: attributes)
        }
    }


    @MainActor
    static func buildHorizonRingNode(from points: [ArcPoint]) -> SCNNode {
        let containerNode : SCNNode = SCNNode()

        for (index, point) in points.enumerated().dropFirst() {
            let previous = points[index - 1]
            let segment  = buildLineSegment(from: previous.position, to: point.position, color: point.color, radius: 0.04)
            containerNode.addChildNode(segment)
        }
        return containerNode
    }

    
    @MainActor
    static func buildSunIndicatorNode() -> SCNNode {
        let sphere  : SCNSphere = SCNSphere(radius: 0.75)
        sphere.firstMaterial?.diffuse.contents  = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        sphere.firstMaterial?.emission.contents = UIColor(red: 1.0, green: 0.7,  blue: 0.0, alpha: 0.8)
        sphere.firstMaterial?.lightingModel     = .constant

        let node : SCNNode   = SCNNode(geometry: sphere)

        let halo : SCNSphere = SCNSphere(radius: 0.75)
        halo.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 0.15)
        halo.firstMaterial?.lightingModel    = .constant
        halo.firstMaterial?.isDoubleSided    = true
        node.addChildNode(SCNNode(geometry: halo))

        return node
    }


    @MainActor
    static func buildMoonIndicatorNode(illumination: Double) -> SCNNode {
        let sphere      : SCNSphere = SCNSphere(radius: 0.55)
        let brightness  : Float     = Float(0.4 + illumination * 0.5)
        sphere.firstMaterial?.diffuse.contents  = UIColor(white: CGFloat(brightness), alpha: 1.0)
        sphere.firstMaterial?.emission.contents = UIColor(white: CGFloat(brightness * 0.3), alpha: 1.0)
        sphere.firstMaterial?.lightingModel     = .constant

        let node : SCNNode   = SCNNode(geometry: sphere)

        let halo : SCNSphere = SCNSphere(radius: 0.55)
        halo.firstMaterial?.diffuse.contents = UIColor(white: CGFloat(brightness * 0.4), alpha: 0.15)
        halo.firstMaterial?.lightingModel    = .constant
        halo.firstMaterial?.isDoubleSided    = true
        node.addChildNode(SCNNode(geometry: halo))

        return node
    }

    
    @MainActor
    private static func buildHourLabelNode(hour: Int, position: SCNVector3, color: UIColor, fontSize: CGFloat) -> SCNNode {
        let text : SCNText = SCNText(string: String(format: "%02d:00", hour), extrusionDepth: 0.005)
        text.font                             = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        text.firstMaterial?.diffuse.contents  = color
        text.firstMaterial?.emission.contents = color.withAlphaComponent(0.8)
        text.firstMaterial?.lightingModel     = .constant
        text.isWrapped                        = false

        let (minBound, maxBound) : (SCNVector3, SCNVector3) = text.boundingBox
        
        let billboard : SCNBillboardConstraint = SCNBillboardConstraint()
        billboard.freeAxes = .all

        let node : SCNNode = SCNNode(geometry: text)
        node.position    = position
        node.constraints = [billboard]
        node.pivot       = SCNMatrix4MakeTranslation((maxBound.x - minBound.x) / 2, (maxBound.y - minBound.y) / 2, 0)
         
        return node
    }


    @MainActor
    private static func buildLineSegment(from start: SCNVector3, to end: SCNVector3, color: UIColor, radius: CGFloat) -> SCNNode {
        let deltaX : Float = end.x - start.x
        let deltaY : Float = end.y - start.y
        let deltaZ : Float = end.z - start.z
        let length : Float = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)

        let cylinder : SCNCylinder = SCNCylinder(radius: radius, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.lightingModel    = .constant

        let node : SCNNode = SCNNode(geometry: cylinder)
        node.position = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)

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

    
    nonisolated private static func sunArcColor(altitude: Double) -> UIColor {
        switch altitude {
            case -6..<0 : return UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.9)
            case 0..<6  : return UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 0.95)
            case 6..<12 : return UIColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 0.85)
            default     : return UIColor(red: 1.0, green: 0.95, blue: 0.4, alpha: 0.7)
        }
    }

    nonisolated private static func sunLabelColor(altitude: Double) -> UIColor {
        switch altitude {
            case -6..<0 : return UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 0.9)
            case 0..<6  : return UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.95)
            case 6..<12 : return UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.85)
            default     : return UIColor(red: 1.0, green: 1.0,  blue: 0.6, alpha: 0.75)
        }
    }
}
