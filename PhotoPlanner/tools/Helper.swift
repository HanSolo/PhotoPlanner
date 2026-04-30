//
//  Helper.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import MapKit
import SystemConfiguration


public class Helper {
    public static func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    public static func toDegrees(radians: Double) -> Double {
        return radians * 180 / .pi
    }

    public static func toRadians(degrees: Double) -> Double {
        return degrees * .pi / 180
    }
    
    public static func clamp(min: Double, max: Double, value: Double) -> Double {
        if value < min { return min }
        if value > max { return max }
        return value
    }
    
    public static func distance(x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        let ac: Double = abs(y2 - y1)
        let cb: Double = abs(x2 - x1)
        return hypot(ac, cb)
    }
    
    public static func calc(camera: MKMapPoint, motif: MKMapPoint, focalLengthInMM: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation) throws -> FoVData {
        let distance : Double = camera.distance(to: motif)
        
        if focalLengthInMM < 8 || focalLengthInMM > 2400 { throw FoVError.invalidArgument(message: "Error, focal length must be between 8mm and 2400mm") }
        if aperture < 0.7 || aperture > 99 { throw FoVError.invalidArgument(message: "Error, aperture must be between f/0.7 and f/99"); }
        if distance < 0.01 || distance > 9999 { throw FoVError.invalidArgument(message: "Error, distance must be between 0.01m and 9999m"); }

        let format : SensorFormat = SensorFormat.allCases[Int(sensorFormat)]
        
        let cropFactor: Double = format.cropFactor

        // Do all calculations in metres (because that's sensible).
        let focalLength: Double = focalLengthInMM / 1000.0

        // Let the circle of confusion be 0.0290mm for 35mm film.
        let circleOfConfusion: Double = (0.0290 / 1000.0) / cropFactor

        let hyperFocal    : Double = (focalLength * focalLength) / (aperture * circleOfConfusion) + focalLength
        let nearLimit     : Double = ((hyperFocal - focalLength) * distance) / (hyperFocal + distance - 2 * focalLength);

        let infinite      : Bool   = (hyperFocal - distance) < 0.00000001

        let farLimit      : Double = ((hyperFocal - focalLength) * distance) / (hyperFocal - distance)
        let frontPercent  : Double = (distance - nearLimit) / (farLimit - nearLimit) * 100
        let behindPercent : Double = (farLimit - distance) / (farLimit - nearLimit) * 100
        let total         : Double = farLimit - nearLimit

        let d             : Double = sqrt((format.width * format.width) + (format.height * format.height))
        let diagonalAngle : Double = 2.0 * atan(d / (2.0 * focalLengthInMM))
        let diagonalLength: Double = ((distance * sin(diagonalAngle / 2.0)) / cos(diagonalAngle / 2.0)) * 2.0
        let phi           : Double = asin(2.0 / 3.605551)
        let fovWidth      : Double
        let fovHeight     : Double
        if CameraOrientation.landscape == orientation {
            fovWidth  = cos(phi) * diagonalLength
            fovHeight = sin(phi) * diagonalLength
        } else {
            fovWidth  = sin(phi) * diagonalLength
            fovHeight = cos(phi) * diagonalLength
        }

        let halfFovWidth  : Double = fovWidth * 0.5
        let halfFovHeight : Double = fovHeight * 0.5

        let fovWidthAngle : Double = 2 * asin(halfFovWidth / sqrt((distance * distance) + (halfFovWidth * halfFovWidth)))
        let fovHeightAngle: Double = 2 * asin(halfFovHeight / sqrt((distance * distance) + (halfFovHeight * halfFovHeight)))
        let radius        : Double = sqrt((halfFovWidth * halfFovWidth) + (distance * distance))
                
        return FoVData(camera: camera, motif: motif, focalLength: focalLengthInMM, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation, infinite: infinite, hyperFocal: hyperFocal, nearLimit: nearLimit, farLimit: farLimit, frontPercent: frontPercent, behindPercent: behindPercent, total: total, diagonalAngle: diagonalAngle, diagonalLength: diagonalLength, fovWidth: fovWidth, fovWidthAngle: fovWidthAngle, fovHeight: fovHeight, fovHeightAngle: fovHeightAngle, radius: radius)
    }
    
    public static func updateTriangle(camera: MKMapPoint, motif: MKMapPoint, focalLengthInMM: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation) -> [CLLocationCoordinate2D] {
        do {
            let fovData: FoVData = try calc(camera: camera, motif: motif, focalLengthInMM: focalLengthInMM, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation)
            return calcTrianglePoints(data: fovData)
        } catch {
            // Handle error here
            return []
        }
    }
    
    public static func calcTrianglePoints(data: FoVData) -> [CLLocationCoordinate2D] {
        let halfFovWidthAngle: Double = data.fovWidthAngle / 2.0
        let p1Coordinates : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: Double(data.cameraLocation.coordinate.latitude), longitude: Double(data.cameraLocation.coordinate.longitude))
        let p2Coordinates : CLLocationCoordinate2D = calcCoord(start: data.cameraLocation, distance: data.radius, bearing: -halfFovWidthAngle)
        let p3Coordinates : CLLocationCoordinate2D = calcCoord(start: data.cameraLocation, distance: data.radius, bearing: halfFovWidthAngle)
        return [ p1Coordinates, p2Coordinates, p3Coordinates ]
    }
    
    public static func updateTrapezoid(camera: MKMapPoint, motif: MKMapPoint, focalLengthInMM: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation) -> [CLLocationCoordinate2D] {
        do {
            let data: FoVData = try calc(camera: camera, motif: motif, focalLengthInMM: focalLengthInMM, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation)
            return calcTrapezoidPoints(data: data)
        } catch {
            // Handle error here
            return []
        }
    }
    
    public static func calcTrapezoidPoints(data: FoVData) -> [CLLocationCoordinate2D] {
        let halfFovWidthAngle: Double = data.fovWidthAngle / 2.0
        let radius1          : Double = data.nearLimit / cos(halfFovWidthAngle)
        let radius2          : Double = data.farLimit / cos(halfFovWidthAngle)

        let p1Coordinates : CLLocationCoordinate2D = calcCoord(start: data.cameraLocation, distance: radius1, bearing: -halfFovWidthAngle)
        let p2Coordinates : CLLocationCoordinate2D = calcCoord(start: data.cameraLocation, distance: radius2, bearing: -halfFovWidthAngle)
        let p3Coordinates : CLLocationCoordinate2D = calcCoord(start: data.cameraLocation, distance: radius2, bearing: halfFovWidthAngle)
        let p4Coordinates : CLLocationCoordinate2D = calcCoord(start: data.cameraLocation, distance: radius1, bearing: halfFovWidthAngle)

        return  [ p1Coordinates, p2Coordinates, p3Coordinates, p4Coordinates ]
    }
    
    public static func calcBearing(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> Double {
        let lat1   : Double = toRadians(degrees: Double(location1.latitude))
        let lon1   : Double = Double(location1.longitude)
        let lat2   : Double = toRadians(degrees: Double(location2.latitude))
        let lon2   : Double = Double(location2.longitude)
        let dLon   : Double = toRadians(degrees: lon2 - lon1);
        let y      : Double = sin(dLon) * cos(lat2)
        let x      : Double = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing: Double = (toDegrees(radians: atan2(y, x)) + 360).truncatingRemainder(dividingBy: 360)
        return bearing
    }
    
    public static func calcBearingInDegree(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> Double {
        return calcBearingInDegree(lat1: location1.latitude, lon1: location1.longitude, lat2: location2.latitude, lon2: location2.longitude)
    }
    public static func calcBearingInDegree(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let lat1Rad : Double = toRadians(degrees: lat1)
        let lon1Rad : Double = toRadians(degrees: lon1)
        let lat2Rad : Double = toRadians(degrees: lat2)
        let lon2Rad : Double = toRadians(degrees: lon2)
        let y       : Double = sin(lon2Rad - lon1Rad) * cos(lat2Rad)
        let x       : Double = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(lon2Rad - lon1Rad)
        let t       : Double = atan2(y, x)
        let brng    : Double = (t * 180 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
        return brng
    }
    
    public static func calcCoord(start: MKMapPoint, distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        let lat1   = toRadians(degrees: Double(start.coordinate.latitude))
        let lon1   = toRadians(degrees: Double(start.coordinate.longitude))
        let radius = distance / Constants.EARTH_RADIUS

        let lat2 = asin(sin(lat1) * cos(radius) + cos(lat1) * sin(radius) * cos(bearing))
        var lon2 = lon1 + atan2(sin(bearing) * sin(radius) * cos(lat1), cos(radius) - sin(lat1) * sin(lat2))
        lon2 = (lon2 + 3 * .pi).truncatingRemainder(dividingBy: (2 * .pi)) - .pi
        
        return CLLocationCoordinate2D(latitude: toDegrees(radians: lat2), longitude: toDegrees(radians: lon2))
    }
    
    public static func rotatePointAroundCenter(point: MKMapPoint, rotationCenter: MKMapPoint, angleRad: Double) -> MKMapPoint {
        return MKMapPoint(rotatePointAroundCenter(location: point.coordinate, around: rotationCenter.coordinate, angleRad: angleRad))
    }
    public static func rotatePointAroundCenter(location: CLLocationCoordinate2D, around: CLLocationCoordinate2D, angleRad: Double) -> CLLocationCoordinate2D {
        let piFactor             : Double = .pi / 180
        let locationLatRad       : Double = location.latitude * piFactor
        let locationLonRad       : Double = location.longitude * piFactor
        let rotationCenterLatRad : Double = around.latitude * piFactor
        let rotationCenterLonRad : Double = around.longitude * piFactor

        // Convert both points to Cartesian (x, y) on a flat plane
        let x : Double = (locationLonRad - rotationCenterLonRad) * cos(rotationCenterLatRad)
        let y : Double = locationLatRad - rotationCenterLatRad

        // Apply 2D rotation matrix
        let cosA     : Double = cos(angleRad)
        let sinA     : Double = sin(angleRad)
        let xRotated : Double = x * cosA - y * sinA
        let yRotated : Double = x * sinA + y * cosA

        // Convert back to lat/lon
        let newLatRad : Double = yRotated + rotationCenterLatRad
        let newLonRad : Double = xRotated / cos(rotationCenterLatRad) + rotationCenterLonRad

        return CLLocationCoordinate2D(latitude: newLatRad * 180 / .pi, longitude: newLonRad * 180 / .pi)
    }
        
    public static func getPointByAngle(point: MKMapPoint, angleDeg: Double) -> MKMapPoint {
        return rotatePointAroundCenter(point: MKMapPoint(CLLocationCoordinate2D(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude + .pi/2)), rotationCenter: point, angleRad: toRadians(degrees: angleDeg))
    }
    public static func getPointByAngle(point: MKMapPoint, angleDeg: Double, distance: Double) -> MKMapPoint {
        return rotatePointAroundCenter(point: MKMapPoint(x: point.x, y: point.y + distance), rotationCenter: point, angleRad: toRadians(degrees: angleDeg))
    }
    
    public static func getLatLonByAngleAndDistance(lat :Double, lon :Double, distanceInMeters :Double, angleDeg: Double) -> (Double, Double){
        let earthRadius      :Double = Constants.EARTH_RADIUS // m
        let radians          :Double = toRadians(degrees: angleDeg)
        
        let originLatRad     :Double = toRadians(degrees: lat)
        let originLonRad     :Double = toRadians(degrees: lon)
        
        let distanceToRadius :Double = distanceInMeters / earthRadius
        
        let targetLatRad     :Double = asin(sin(originLatRad) * cos(distanceToRadius) + cos(originLatRad) * sin(distanceToRadius) * cos(radians))
        let targetLonRad     :Double = originLonRad + atan2(sin(radians) * sin(distanceToRadius) * cos(originLatRad), cos(distanceToRadius) - sin(originLatRad) * sin(targetLatRad))
        
        let targetLat        :Double = toDegrees(radians: targetLatRad)
        let targetLon        :Double = toDegrees(radians: targetLonRad)
        
        return (targetLat, targetLon)
    }
    
    // return date string with given format e.g. "dd.MM.yyyy HH:mm:ss"
    public static func dateToString(fromDate date:Date, formatString :String) -> String {
        let dateFormatter        = DateFormatter()
        dateFormatter.timeZone   = TimeZone.current
        dateFormatter.dateFormat = formatString.isEmpty ? "dd.MM.yyyy HH:mm:ss" : formatString
        return dateFormatter.string(from: date)
    }
}


