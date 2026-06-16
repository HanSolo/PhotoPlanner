//
//  GalacticConverter.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 16.06.26.
//

import Foundation
import SwiftUI
import CoreLocation


struct GalacticConverter {

    // IAU 1958 galactic coordinate system constants
    // North Galactic Pole in equatorial coordinates (J2000)
    private static let ngpRA     : Double = 192.85948   // degrees
    private static let ngpDec    : Double =  27.12825   // degrees
    private static let l0        : Double =  32.93192   // Galactic longitude of ascending node in degrees
    
    // Precise J2000 galactic center equatorial coordinates used directly to avoid approximation errors in galacticToEquatorial
    static let galacticCenterRA  :  Double = 266.405
    static let galacticCenterDec : Double = -28.936

    
    // Converts galactic coordinates (longitude l, latitude b) to equatorial coordinates (right ascension, declination) in degrees.
    static func galacticToEquatorial(l: Double, b: Double) -> (ra: Double, dec: Double) {
        // IAU 1958 galactic coordinate system
        // NGP: RA = 192.25°, Dec = +27.4° (B1950, but we'll work in these and convert)
        // Ascending node of galactic plane on equator: 33°
        // Working directly with the B1950 system then converting is more reliable
        // NGP position in B1950: RA = 192.25°, Dec = 27.4°
        // Galactic longitude of ascending node = 33°

        let lRad    : Double = (l - 33.0) * .pi / 180
        let bRad    : Double = b           * .pi / 180
        let decNGP  : Double = 27.4        * .pi / 180
        //let raNGP   : Double = 192.25      * .pi / 180 // not used

        let sinDec  : Double = sin(bRad) * sin(decNGP) + cos(bRad) * cos(decNGP) * sin(lRad)

        let dec1950 : Double = asin(max(-1, min(1, sinDec))) * 180 / .pi

        let cosA    : Double = cos(bRad) * cos(lRad)
        let sinA    : Double = sin(bRad) * cos(decNGP) - cos(bRad) * sin(decNGP) * sin(lRad)

        var ra1950  : Double = atan2(cosA, sinA) * 180 / .pi + 192.25
        ra1950 = ra1950.truncatingRemainder(dividingBy: 360)
        if ra1950 < 0 { ra1950 += 360 }

        // Convert B1950 to J2000 using the standard precession offset
        // Approximate but accurate to ~0.1° for our purposes
        let ra2000  : Double = ra1950  + 0.640
        let dec2000 : Double = dec1950 + 0.278

        return (ra2000, dec2000)
    }

    // Converts equatorial (RA, Dec) to horizontal (altitude, azimuth) for an observer at the given coordinate and time.
    static func equatorialToHorizontal(ra: Double, dec: Double, coordinate: CLLocationCoordinate2D, time: Date) -> (altitude: Double, azimuth: Double) {
        let julianDate  : Double = time.timeIntervalSince1970 / 86400.0 + 2440587.5
        let jd0         : Double = floor(julianDate - 0.5) + 0.5
        let T0          : Double = (jd0 - 2451545.0) / 36525.0
        let utHours     : Double = (julianDate - jd0) * 24.0

        let gmst0       : Double = (6.697374558 + 2400.0513369 * T0 + 0.0000258622 * T0 * T0 - 1.7222e-9 * T0 * T0 * T0) * 15.0
        let gmst        : Double = (gmst0 + 360.98564724 * utHours / 24.0).truncatingRemainder(dividingBy: 360)

        var lha         : Double = (gmst + coordinate.longitude - ra).truncatingRemainder(dividingBy: 360)
        if lha < 0      { lha += 360 }

        let lhaRad      : Double = lha               * .pi / 180
        let decRad      : Double = dec               * .pi / 180
        let latRad      : Double = coordinate.latitude * .pi / 180

        let sinAlt      : Double = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(lhaRad)
        let altitude    : Double = asin(max(-1, min(1, sinAlt))) * 180 / .pi

        let cosAz       : Double = (sin(decRad) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(max(-1, min(1, sinAlt)))))
        var azimuth     : Double = acos(max(-1, min(1, cosAz))) * 180 / .pi
        if sin(lhaRad) > 0 { azimuth = 360 - azimuth }

        return (altitude, azimuth)
    }

    // Samples the full galactic plane at the given time and location.
    // Returns an array of (altitude, azimuth) pairs for each sample point.
    // stepDegrees controls the resolution, 5° gives 72 points.
    static func galacticPlanePoints(at coordinate: CLLocationCoordinate2D, time: Date, stepDegrees: Double = 3.0) -> [(altitude: Double, azimuth: Double)] {
        var points : [(Double, Double)] = []
        var l      : Double             = 0.0
        while l < 360.0 {
            let (ra, dec) : (Double, Double) = galacticToEquatorial(l: l, b: 0)
            let (alt, az) : (Double, Double) = equatorialToHorizontal(ra: ra, dec: dec, coordinate: coordinate, time: time)
            points.append((alt, az))
            l += stepDegrees
        }
        return points
    }

    // Samples the galactic plane at multiple latitudes to draw a band with the given half width in galactic latitude degrees.
    static func galacticBandPoints(at coordinate: CLLocationCoordinate2D, time: Date, stepDegrees: Double = 3.0, bandLatitudes: [Double] = [-8, -4, 0, 4, 8]) -> [[(altitude: Double, azimuth: Double)]] {
        return bandLatitudes.map { b in
            var points: [(Double, Double)] = []
            var l     : Double             = 0.0
            while l < 360.0 {
                let (ra, dec) = galacticToEquatorial(l: l, b: b)
                let (alt, az) = equatorialToHorizontal(ra: ra, dec: dec, coordinate: coordinate, time: time)
                points.append((alt, az))
                l += stepDegrees
            }
            return points
        }
    }
}
