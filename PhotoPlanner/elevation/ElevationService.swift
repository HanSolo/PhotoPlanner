//
//  ElevationService.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import Foundation
import CoreLocation
import SwiftUI


actor ElevationService {
    private let baseURL : String = "https://api.opentopodata.org/v1/srtm90m"
    private let session : URLSession

    
    init(session: URLSession = .shared) {
        self.session = session
    }

    
    func interpolatedCoordinates(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, interval: CLLocationDistance = 50) -> [CLLocationCoordinate2D] {
        let startLocation : CLLocation         = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation   : CLLocation         = CLLocation(latitude: end.latitude,   longitude: end.longitude)
        let totalDistance : CLLocationDistance = startLocation.distance(from: endLocation)

        guard totalDistance > 0 else { return [start] }

        let stepCount = max(1, Int((totalDistance / interval).rounded()))
        return (0...stepCount).map { step in
            let fraction = Double(step) / Double(stepCount)
            return interpolate(from: start, to: end, fraction: fraction)
            //return start.interpolated(to: end, fraction: fraction)
        }
    }

    func fetchElevations(for coordinates: [CLLocationCoordinate2D], chunkSize: Int = 100) async throws -> [ElevationPoint] {
        let chunks = stride(from: 0, to: coordinates.count, by: chunkSize).map {
            Array(coordinates[$0..<min($0 + chunkSize, coordinates.count)])
        }

        var results: [ElevationPoint] = []
        for (index, chunk) in chunks.enumerated() {
            if index > 0 {
                // Respect the 1 req/sec rate limit
                try await Task.sleep(for: .seconds(1))
            }
            let points = try await fetchChunk(for: chunk)
            results.append(contentsOf: points)
        }
        return results
    }
    
    private func fetchChunk(for coordinates: [CLLocationCoordinate2D]) async throws -> [ElevationPoint] {
        //guard let url = URL(string: baseURL) else { throw ElevationError.invalidURL }
        let locationString = coordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")

        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "locations", value: locationString)]

        var request : URLRequest = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        //if let responseString = String(data: data, encoding: .utf8) { debugPrint(responseString) }

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ElevationError.invalidResponse
        }
        
        struct OpenTopoResponse: Decodable {
            let status  : String
            let results : [Result]
            
            struct Result  : Decodable {
                let elevation : Double
                let location  : Location
            }
            
            struct Location: Decodable {
                let lat : Double
                let lng : Double
            }
        }

        let decoded = try JSONDecoder().decode(OpenTopoResponse.self, from: data)

        return decoded.results.map {
            ElevationPoint(coordinate : CLLocationCoordinate2D(latitude  : $0.location.lat, longitude : $0.location.lng), elevation : $0.elevation)
        }
    }

    func elevationProfile(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, interval: CLLocationDistance = 100, cameraHeight: Double = 1.5, subjectHeight: Double = 0.0) async throws -> ElevationProfile {
            let coordinates : [CLLocationCoordinate2D] = interpolatedCoordinates(from: start, to: end, interval: interval)
            let points      : [ElevationPoint]         = try await fetchElevations(for: coordinates)
            return ElevationProfile(points: points, cameraHeight: cameraHeight, subjectHeight: subjectHeight)
        }
    
    func interpolate(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude:  start.latitude  + (end.latitude  - start.latitude)  * fraction, longitude: start.longitude + (end.longitude - start.longitude) * fraction)
    }
}

// TODO: Check whether it's still needed, replaced by interpolate method in ElevationService
extension CLLocationCoordinate2D {

    func interpolated(to other: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude:  latitude  + (other.latitude  - latitude)  * fraction,longitude: longitude + (other.longitude - longitude) * fraction)
    }
}
