//
//  NetworkMonitor.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import Foundation
import Network
import SwiftUI
internal import Combine


class NetworkMonitor: ObservableObject {
    private let networkMonitor = NWPathMonitor()

    var isConnected : Bool  = false {
        didSet {
            Task {
                self.isConnectedToInternet = await RestController.isConnected()
            }
        }
    }
    
    @Published var isConnectedToInternet : Bool = false

    
    init() {
        networkMonitor.pathUpdateHandler = { path in
            self.isConnected = path.status == .satisfied
            Task {
                await MainActor.run {
                    self.objectWillChange.send()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global())
    }
}
