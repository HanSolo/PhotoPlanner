//
//  CLLocationCoordinate2D+fetchCityAndCountry.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import MapKit


extension CLLocationCoordinate2D {
    
    func fetchCityAndCountry() async throws -> (city: String, country: String) {
        guard let request : MKReverseGeocodingRequest = MKReverseGeocodingRequest(location: CLLocation(latitude: self.latitude, longitude: self.longitude)),
              let addressRepresentations = try await request.mapItems.first?.addressRepresentations else {
            throw MKError(.decodingFailed)
        }        
        return (addressRepresentations.cityName ?? "", addressRepresentations.regionName ?? "")
    }
    
    func fetchCityAndCountryCode() async throws -> (city: String, countryCode: String) {
        guard let request : MKReverseGeocodingRequest = MKReverseGeocodingRequest(location: CLLocation(latitude: self.latitude, longitude: self.longitude)),
              let addressRepresentations = try await request.mapItems.first?.addressRepresentations else {
            throw MKError(.decodingFailed)
        }
        return (addressRepresentations.cityName ?? "", addressRepresentations.region?.identifier ?? "")
    }
    
    /// Returns a new coordinate offset by the given distance
        /// in kilometres in the given compass bearing (degrees clockwise from north).
        func coordinateByOffsetting(distanceKilometres: Double, bearingDegrees: Double) -> CLLocationCoordinate2D {
            let earthRadiusKilometres : Double = 6371.0
            let bearingRadians        : Double = bearingDegrees * .pi / 180
            let distanceRadians       : Double = distanceKilometres / earthRadiusKilometres

            let latitudeRadians  : Double = latitude  * .pi / 180
            let longitudeRadians : Double = longitude * .pi / 180

            let newLatitudeRadians : Double = asin(
                sin(latitudeRadians) * cos(distanceRadians) +
                cos(latitudeRadians) * sin(distanceRadians) * cos(bearingRadians)
            )
            let newLongitudeRadians : Double = longitudeRadians + atan2(
                sin(bearingRadians) * sin(distanceRadians) * cos(latitudeRadians),
                cos(distanceRadians) - sin(latitudeRadians) * sin(newLatitudeRadians)
            )

            return CLLocationCoordinate2D(latitude:  newLatitudeRadians  * 180 / .pi, longitude: newLongitudeRadians * 180 / .pi)
        }
}
