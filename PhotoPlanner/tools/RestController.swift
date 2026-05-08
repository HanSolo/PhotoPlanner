//
//  RestController.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import Foundation
import Network
import SwiftUI


class RestController {
    public static func isConnected() async -> Bool {
        let sessionConfig : URLSessionConfiguration = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest  = 2.0
        sessionConfig.timeoutIntervalForResource = 2.0
        
        let urlString : String      = "https://apple.com"
        let session   : URLSession  = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: .main)
        let finalUrl  : URL         = URL(string: urlString)!
        var request   : URLRequest  = URLRequest(url: finalUrl)
        request.httpMethod = "HEAD"
        do {
            let resp : (Data,URLResponse) = try await session.data(for: request)
            
            if let httpResponse = resp.1 as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            } else {
                return false
            }
        } catch {
            return false
        }
    }        
}
