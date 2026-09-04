//
//  StormCellService.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.09.26.
//

import Foundation


final class StormCellService {
    let baseURL : URL = URL(string: "http://hansolo.eu:8081")!

    
    func fetchStormCells(lat: Double? = nil, lon: Double? = nil,radiusKm: Double? = nil) async throws -> [StormCellFeature] {
        guard var components : URLComponents = URLComponents(url: baseURL.appendingPathComponent("v2/storm-cells"), resolvingAgainstBaseURL: false) else {
            throw StormCellError.badURL
        }

        var queryItems: [URLQueryItem] = []
        if let lat      { queryItems.append(URLQueryItem(name: "lat", value: String(lat))) }
        if let lon      { queryItems.append(URLQueryItem(name: "lon", value: String(lon))) }
        if let radiusKm { queryItems.append(URLQueryItem(name: "radius_km", value: String(radiusKm))) }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url : URL = components.url else { throw StormCellError.badURL }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 503 { throw StormCellError.detectionDisabled }
            guard (200...299).contains(http.statusCode) else { throw StormCellError.httpError(http.statusCode) }
        }

        let decoded = try JSONDecoder().decode(StormCellResponse.self, from: data)
        return decoded.features
    }
}
