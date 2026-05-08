//
//  ElevationError.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import Foundation
import CoreLocation


enum ElevationError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
            case .invalidURL           : return "Invalid API URL"
            case .networkError(let e)  : return "Network error: \(e.localizedDescription)"
            case .invalidResponse      : return "Invalid response from server"
            case .decodingError(let e) : return "Decoding error: \(e.localizedDescription)"
        }
    }
}
