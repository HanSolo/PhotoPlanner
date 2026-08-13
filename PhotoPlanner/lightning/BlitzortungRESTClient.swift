//
//  BlitzortungRESTClient.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.08.26.
//

import Foundation


actor BlitzortungRESTClient {

    private struct StrikeJSON: Decodable {
        let time   : Int64    // nanoseconds since Unix epoch
        let lat    : Double
        let lon    : Double
        let pol    : Int?
        let status : Int?
        let region : Int?
    }
    
    private let username        : String
    private let password        : String
    private let session         : URLSession = URLSession.shared
    private var seenStrikeTimes : [String:Date] = [:]
    
    
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }


    // Fetches strikes newer than `afterTimestamp` (nanoseconds since epoch)
    // within the given bounding box. Pass 0 to get the last `maxCount` strikes.
    func fetchStrikes(north: Double, south: Double, east: Double, west: Double, afterTimestamp: Int64 = 0, maxCount: Int = 200) async -> [LightningStrike] {
        guard let url : URL        = buildURL(north: north, south: south, east: east, west: west, afterTimestamp: afterTimestamp, maxCount: maxCount) else { return [] }
        var request   : URLRequest = URLRequest(url: url)
        request.timeoutInterval    = 10

        // Basic auth via URL credentials
        let credentials : String = "\(username):\(password)"
        if let data = credentials.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return [] }

            return parse(data)
        } catch {
            return []   // fail open, never block the overlay
        }
    }

    private func buildURL(north: Double, south: Double, east: Double, west: Double, afterTimestamp: Int64, maxCount: Int) -> URL? {
        var components = URLComponents(string: "https://data.blitzortung.org/Data/Protected/last_strikes.php")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "north",  value: "\(north)"),
            URLQueryItem(name: "south",  value: "\(south)"),
            URLQueryItem(name: "east",   value: "\(east)"),
            URLQueryItem(name: "west",   value: "\(west)"),
            URLQueryItem(name: "number", value: "\(maxCount)"),
            URLQueryItem(name: "sig",    value: "0")
        ]
        if afterTimestamp > 0 {
            items.append(URLQueryItem(name: "time", value: "\(afterTimestamp)"))
        }
        components?.queryItems = items
        return components?.url
    }

    // Blitzortung returns one JSON object per line, not a JSON array.
    private func parse(_ data: Data) -> [LightningStrike] {
        guard let text : String = String(data: data, encoding: .utf8) else { return [] }
        return text.components(separatedBy: .newlines).compactMap { line -> LightningStrike? in
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json     = try? JSONDecoder().decode(StrikeJSON.self, from: lineData)
            else { return nil }

            let timestamp = Date(timeIntervalSince1970: Double(json.time) / 1_000_000_000)
            let key       = "\(json.time)_\(json.region ?? 0)_\(json.status ?? 0)"
                        
            seenStrikeTimes[key] = Date()
            
            let cutoff = Date().addingTimeInterval(-300)
            seenStrikeTimes = seenStrikeTimes.filter { $0.value > cutoff }
            
            return LightningStrike(latitude: json.lat, longitude: json.lon, timestamp: timestamp, nanoseconds: json.time, polarity: json.pol ?? 0)
        }
    }
}
