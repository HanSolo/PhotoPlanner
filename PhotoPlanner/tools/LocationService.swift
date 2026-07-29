//
//  LocationService.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.07.26.
//

import Foundation
internal import Combine
import MapKit


class LocationService: NSObject, ObservableObject {

    enum LocationStatus: Equatable {
        case idle
        case noResults
        case isSearching
        case error(String)
        case result
    }

    @Published  var queryFragment : String                    = ""
    @Published  var status        : LocationStatus            = .idle
    @Published  var searchResults : [MKLocalSearchCompletion] = []

    private var queryCancellable : AnyCancellable?
    private let searchCompleter  : MKLocalSearchCompleter!

    
    init(searchCompleter: MKLocalSearchCompleter = MKLocalSearchCompleter()) {
        self.searchCompleter = searchCompleter
        super.init()
        self.searchCompleter.delegate = self

        queryCancellable = $queryFragment
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main, options: nil)
            .sink(receiveValue: { fragment in
                self.status = .isSearching
                if !fragment.isEmpty {
                    self.searchCompleter.queryFragment = fragment
                } else {
                    self.status        = .idle
                    self.searchResults = []
                }
        })
    }
}
