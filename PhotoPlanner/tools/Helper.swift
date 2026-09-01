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
    
    public static func toDegrees(_ radians: Double) -> Double {
        return radians * 180 / .pi
    }
    public static func toRadians(_ degrees: Double) -> Double {
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
        
    public static func calcFoV(camera: MKMapPoint, subject: MKMapPoint, focalLengthInMM: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation, tc1: Teleconverter, tc2: Teleconverter) throws -> FoVData {
        let distance : Double = camera.distance(to: subject)
        
        if focalLengthInMM < 8    || focalLengthInMM > 2400 { throw FoVError.invalidArgument(message: "Error, focal length must be between 8mm and 2400mm") }
        if aperture        < 0.7  || aperture        >   99 { throw FoVError.invalidArgument(message: "Error, aperture must be between f/0.7 and f/99"); }
        if distance        < 0.01 || distance        > 9999 { throw FoVError.invalidArgument(message: "Error, distance must be between 0.01m and 9999m"); }
            
        let format : SensorFormat = SensorFormat.allCases[Int(sensorFormat)]
        
        let cropFactor: Double = format.cropFactor

        // Modified values form Teleconverter 1 and 2
        let tc1ModifiedValues : Teleconverter.TcModifiedValues = tc1.calculate(focalLength: focalLengthInMM, aperture: aperture)
        let tc2ModifiedValues : Teleconverter.TcModifiedValues = tc2.calculate(focalLength: tc1ModifiedValues.exactFocalLength, aperture: tc1ModifiedValues.exactAperture)
        let modifiedFocalLength : Double = tc2ModifiedValues.exactFocalLength
        let modifiedAperture    : Double = tc2ModifiedValues.exactAperture
        
        // Do all calculations in metres.
        let focalLength: Double = modifiedFocalLength / 1000.0 //focalLengthInMM / 1000.0

        // Let the circle of confusion be 0.0290mm for 35mm film.
        let circleOfConfusion: Double = (0.0290 / 1000.0) / cropFactor

        let hyperFocal    : Double = (focalLength * focalLength) / (modifiedAperture * circleOfConfusion) + focalLength
        let nearLimit     : Double = ((hyperFocal - focalLength) * distance) / (hyperFocal + distance - 2 * focalLength);

        let infinite      : Bool   = (hyperFocal - distance) < 0.00000001

        let farLimit      : Double = ((hyperFocal - focalLength) * distance) / (hyperFocal - distance)
        let frontPercent  : Double = (distance - nearLimit) / (farLimit - nearLimit) * 100
        let behindPercent : Double = (farLimit - distance) / (farLimit - nearLimit) * 100
        let total         : Double = farLimit - nearLimit

        let d             : Double = sqrt((format.width * format.width) + (format.height * format.height))
        let diagonalAngle : Double = 2.0 * atan(d / (2.0 * modifiedFocalLength)) //focalLengthInMM))
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
                
        return FoVData(camera: camera, subject: subject, focalLength: modifiedFocalLength /*focalLengthInMM*/, aperture: modifiedAperture /*aperture*/, sensorFormat: sensorFormat, orientation: orientation, infinite: infinite, hyperFocal: hyperFocal, nearLimit: nearLimit, farLimit: farLimit, frontPercent: frontPercent, behindPercent: behindPercent, total: total, diagonalAngle: diagonalAngle, diagonalLength: diagonalLength, fovWidth: fovWidth, fovWidthAngle: fovWidthAngle, fovHeight: fovHeight, fovHeightAngle: fovHeightAngle, radius: radius)
    }
    
    public static func updateTriangle(camera: MKMapPoint, subject: MKMapPoint, focalLengthInMM: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation, tc1: Teleconverter, tc2: Teleconverter) -> [CLLocationCoordinate2D] {
        do {
            let fovData: FoVData = try calcFoV(camera: camera, subject: subject, focalLengthInMM: focalLengthInMM, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation, tc1: tc1, tc2: tc2)
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
    
    public static func updateTrapezoid(camera: MKMapPoint, subject: MKMapPoint, focalLengthInMM: Double, aperture: Double, sensorFormat: Int, orientation: CameraOrientation, tc1: Teleconverter, tc2: Teleconverter) -> [CLLocationCoordinate2D] {
        do {
            let data: FoVData = try calcFoV(camera: camera, subject: subject, focalLengthInMM: focalLengthInMM, aperture: aperture, sensorFormat: sensorFormat, orientation: orientation, tc1: tc1, tc2: tc2)
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
    
    public static func calcHyperFocalDistancePoints(data: FoVData) -> [CLLocationCoordinate2D] {
        let p1Coordinates : CLLocationCoordinate2D = calcCoord(start: data.cameraLocation, distance: data.hyperFocal, bearing: -data.fovWidthAngle * 0.5)
        let p2Coordinates : CLLocationCoordinate2D = calcCoord(start: data.cameraLocation, distance: data.hyperFocal, bearing: data.fovWidthAngle * 0.5)
        return  [ p1Coordinates, p2Coordinates ]
    }
    
    public static func calcBearing(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> Double {
        let lat1   : Double = toRadians(Double(location1.latitude))
        let lon1   : Double = Double(location1.longitude)
        let lat2   : Double = toRadians(Double(location2.latitude))
        let lon2   : Double = Double(location2.longitude)
        let dLon   : Double = toRadians(lon2 - lon1);
        let y      : Double = sin(dLon) * cos(lat2)
        let x      : Double = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing: Double = (toDegrees(atan2(y, x)) + 360).truncatingRemainder(dividingBy: 360)
        return bearing
    }
    
    public static func calcAzimuth(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> Double {
        let lat1     : Double = toRadians(location1.latitude)
        let lat2     : Double = toRadians(location2.latitude)
        let deltaLon : Double = toRadians(location2.longitude - location1.longitude)
        let x        : Double = sin(deltaLon) * cos(lat2)
        let y        : Double = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let bearing  : Double = atan2(x, y)
        return (toDegrees(bearing) + 360).truncatingRemainder(dividingBy: 360) // Convert to degrees and normalize to 0–360
    }

    public static func calcBearingInDegree(location1: CLLocationCoordinate2D, location2: CLLocationCoordinate2D) -> Double {
        return calcBearingInDegree(lat1: location1.latitude, lon1: location1.longitude, lat2: location2.latitude, lon2: location2.longitude)
    }
    public static func calcBearingInDegree(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let lat1Rad : Double = toRadians(lat1)
        let lon1Rad : Double = toRadians(lon1)
        let lat2Rad : Double = toRadians(lat2)
        let lon2Rad : Double = toRadians(lon2)
        let y       : Double = sin(lon2Rad - lon1Rad) * cos(lat2Rad)
        let x       : Double = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(lon2Rad - lon1Rad)
        let t       : Double = atan2(y, x)
        let brng    : Double = (t * 180 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
        return brng
    }
    
    public static func calcCoord(start: MKMapPoint, distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        return calcCoord(start: start.coordinate, distance: distance, bearing: bearing)
    }
    public static func calcCoord(start: CLLocationCoordinate2D, distance: Double, bearing: Double) -> CLLocationCoordinate2D {
        let lat1   = toRadians(Double(start.latitude))
        let lon1   = toRadians(Double(start.longitude))
        let radius = distance / Constants.EARTH_RADIUS

        let lat2 = asin(sin(lat1) * cos(radius) + cos(lat1) * sin(radius) * cos(bearing))
        var lon2 = lon1 + atan2(sin(bearing) * sin(radius) * cos(lat1), cos(radius) - sin(lat1) * sin(lat2))
        lon2 = (lon2 + 3 * .pi).truncatingRemainder(dividingBy: (2 * .pi)) - .pi
        
        return CLLocationCoordinate2D(latitude: toDegrees(lat2), longitude: toDegrees(lon2))
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
    public static func rotatePointAroundRotationCenter(x: Double, y: Double, rotationCenterX: Double, rotationCenterY: Double, angleDeg: Double) -> (Double, Double) {
        let rad : Double = toRadians(angleDeg)
        let sin : Double = sin(rad)
        let cos : Double = cos(rad)
        let nX  : Double = rotationCenterX + (x - rotationCenterX) * cos - (y - rotationCenterY) * sin
        let nY  : Double = rotationCenterY + (x - rotationCenterX) * sin + (y - rotationCenterY) * cos
        return (nX, nY)
    }
        
    public static func getPointByAngle(point: MKMapPoint, angleDeg: Double) -> MKMapPoint {
        return rotatePointAroundCenter(point: MKMapPoint(CLLocationCoordinate2D(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude + .pi/2)), rotationCenter: point, angleRad: toRadians(angleDeg))
    }
    public static func getPointByAngle(point: MKMapPoint, angleDeg: Double, distance: Double) -> MKMapPoint {
        return rotatePointAroundCenter(point: MKMapPoint(x: point.x, y: point.y + distance), rotationCenter: point, angleRad: toRadians(angleDeg))
    }
    
    public static func getLatLonByAngleAndDistance(lat :Double, lon :Double, distanceInMeters :Double, angleDeg: Double) -> (Double, Double){
        let earthRadius      :Double = Constants.EARTH_RADIUS // m
        let radians          :Double = toRadians(angleDeg)
        
        let originLatRad     :Double = toRadians(lat)
        let originLonRad     :Double = toRadians(lon)
        
        let distanceToRadius :Double = distanceInMeters / earthRadius
        
        let targetLatRad     :Double = asin(sin(originLatRad) * cos(distanceToRadius) + cos(originLatRad) * sin(distanceToRadius) * cos(radians))
        let targetLonRad     :Double = originLonRad + atan2(sin(radians) * sin(distanceToRadius) * cos(originLatRad), cos(distanceToRadius) - sin(originLatRad) * sin(targetLatRad))
        
        let targetLat        :Double = toDegrees(targetLatRad)
        let targetLon        :Double = toDegrees(targetLonRad)
        
        return (targetLat, targetLon)
    }
    
    public static func dateToString(fromDate date: Date, formatString: String) -> String {
        return dateToString(fromDate: date, formatString: formatString, timezone: TimeZone.current)
    }
    public static func dateToString(fromDate date: Date, formatString: String, timezoneIdentifier: String) -> String {
        return dateToString(fromDate: date, formatString: formatString, timezone: TimeZone(identifier: timezoneIdentifier) ?? .current)
    }
    public static func dateToString(fromDate date: Date, formatString: String, timezone: TimeZone) -> String {
        let dateFormatter        = DateFormatter()
        dateFormatter.timeZone   = timezone
        dateFormatter.dateFormat = formatString.isEmpty ? "dd.MM.yyyy HH:mm:ss" : formatString
        return dateFormatter.string(from: date)
    }
    
    public static func secondsToHHMMString(seconds: Double) -> String {
        if seconds.isInfinite || seconds.isNaN { return "--:--" }
        let hhmmss : (Int, Int) = secondsToHHMM(seconds: seconds)
        return String(format:"%02d:%02d", hhmmss.0, hhmmss.1)
    }
    public static func secondsToHHMM(seconds: Double) -> (Int, Int) {
        if seconds.isInfinite || seconds.isNaN { return (0,0) }
        let minutes : Int = Int((seconds / 60.0).truncatingRemainder(dividingBy: 60.0))
        let hours   : Int = Int((seconds / (3600.0)).truncatingRemainder(dividingBy: 24.0))
        return ( hours, minutes )
    }
    
    public static func secondsToDDHHMMString(seconds: Double) -> String {
        if seconds.isInfinite || seconds.isNaN { return "--:--" }
        let ddhhmm : (Int, Int, Int) = secondsToDDHHMM(seconds: seconds)
        if ddhhmm.0 == 0 {
            return String(format:"%02d:%02d", ddhhmm.1, ddhhmm.2)
        } else {
            return String(format:"%02d:%02d:%02d", ddhhmm.0, ddhhmm.1, ddhhmm.2)
        }
        
    }
    public static func secondsToDDHHMM(seconds: Double) -> (Int, Int, Int) {
        if seconds.isInfinite || seconds.isNaN { return (0, 0, 0) }
        let minutes : Int = Int((seconds / 60.0).truncatingRemainder(dividingBy: 60.0))
        let hours   : Int = Int((seconds / (3_600.0)).truncatingRemainder(dividingBy: 24.0))
        let days    : Int = Int((seconds / (86_400.0)))
        return ( days, hours, minutes )
    }
    
    public static func secondsToHHMMSSString(seconds: Double) -> String {
        if seconds.isInfinite || seconds.isNaN { return "--:--:--"}
        let hhmmss : (Int, Int, Int) = secondsToHHMMSS(seconds: seconds)
        return String(format:"%02d:%02d:%02d", hhmmss.0, hhmmss.1, hhmmss.2)
    }
    public static func secondsToHHMMSS(seconds: Double) -> (Int, Int, Int) {
        if seconds.isInfinite || seconds.isNaN { return (0, 0, 0) }
        let secs    : Int = Int(seconds.truncatingRemainder(dividingBy: 60))
        let minutes : Int = Int((seconds / 60.0).truncatingRemainder(dividingBy: 60.0))
        let hours   : Int = Int((seconds / (3600.0)).truncatingRemainder(dividingBy: 24.0))
        return ( hours, minutes, secs )
    }
    
    public static func kphToBeaufort(_ kph: Double) -> Int {
        switch kph {
            case ..<1    : return 0
            case 1..<6   : return 1
            case 6..<12  : return 2
            case 12..<20 : return 3
            case 20..<29 : return 4
            case 29..<39 : return 5
            case 39..<50 : return 6
            case 50..<62 : return 7
            case 62..<75 : return 8
            default      : return 9
        }
    }
    
    public static func boostCloudOpacity(_ image: UIImage, factor: CGFloat = 3.0) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        // Multiply alpha channel by factor — clamps to 1.0 automatically
        let alphaBoost = CIFilter(name: "CIColorMatrix")!
        alphaBoost.setValue(ciImage, forKey: kCIInputImageKey)
        // Identity matrix but boost the alpha row (row 3)
        alphaBoost.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        alphaBoost.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        alphaBoost.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        alphaBoost.setValue(CIVector(x: 0, y: 0, z: 0, w: factor), forKey: "inputAVector")  // multiply alpha by factor
        alphaBoost.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")

        guard let output  = alphaBoost.outputImage else { return image }
        let       context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    public static func fetchTimeZone(for location: CLLocationCoordinate2D) async -> TimeZone {
        let request = MKReverseGeocodingRequest(location: CLLocation(latitude: location.latitude, longitude: location.longitude))
        do {
            if let timeZone = try await request?.mapItems.first?.timeZone {
                return timeZone
            } else {
                return .current
            }
        } catch {
            return .current
        }
    }
    
    public static func formatAddress(name: String, address: Address) -> String {
        var txt : String = "\(name)"
        if !address.city.isEmpty {
            if address.zip.isEmpty {
                if address.city.lowercased() != name.lowercased() {
                    txt += "\n\(address.city)"
                }
            } else {
                txt += "\n\(address.zip) \(address.city)"
            }
        }
        if !address.state.isEmpty {
            if address.subState.isEmpty {
                txt += "\n\(address.state)"
            } else {
                txt += "\n\(address.state) \(address.subState)"
            }
        }
        if !address.country.isEmpty {
            txt += "\n\(address.country)\(address.isoCode.isEmpty ? "" : " (\(address.isoCode))")"
        }
        
        return txt
    }
            
    public static func screenPoint(for coordinate: CLLocationCoordinate2D, in region: MKCoordinateRegion, size: CGSize, safeAreaTop: CGFloat = 0, safeAreaBottom: CGFloat = 0 ) -> CGPoint {
        func mercY(_ lat: Double) -> Double {
            let rad : Double = lat * .pi / 180.0
            return log(tan(.pi / 4.0 + rad / 2.0))
        }
        
        let totalH            : CGFloat = size.height
        let offsetFraction    : CGFloat = (safeAreaTop - safeAreaBottom) / 2.0 / totalH
        let adjustedCenterLat : CGFloat = region.center.latitude - offsetFraction * region.span.latitudeDelta

        let minLat            : CGFloat = adjustedCenterLat - region.span.latitudeDelta / 2
        let maxLat            : CGFloat = adjustedCenterLat + region.span.latitudeDelta / 2
        let minLon            : CGFloat = region.center.longitude - region.span.longitudeDelta / 2

        let mercMin           : CGFloat = mercY(minLat)
        let mercMax           : CGFloat = mercY(maxLat)
        let mercCoord         : CGFloat = mercY(coordinate.latitude)

        let xFrac             : CGFloat = (coordinate.longitude - minLon) / region.span.longitudeDelta
        let yFrac             : CGFloat = 1.0 - (mercCoord - mercMin) / (mercMax - mercMin)

        return CGPoint(x: xFrac * size.width, y: yFrac * size.height)
    }
}


