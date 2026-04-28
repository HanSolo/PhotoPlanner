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
        guard let request = MKReverseGeocodingRequest(location: CLLocation(latitude: self.latitude, longitude: self.longitude)),
              let addressRepresentations = try await request.mapItems.first?.addressRepresentations else {
            throw MKError(.decodingFailed)
        }        
        return (addressRepresentations.cityName ?? "", addressRepresentations.regionName ?? "")
    }
    
    func fetchCityAndCountryCode() async throws -> (city: String, countryCode: String) {
        guard let request = MKReverseGeocodingRequest(location: CLLocation(latitude: self.latitude, longitude: self.longitude)),
              let addressRepresentations = try await request.mapItems.first?.addressRepresentations else {
            throw MKError(.decodingFailed)
        }
        return (addressRepresentations.cityName ?? "", addressRepresentations.region?.identifier ?? "")
    }
}
