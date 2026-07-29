//
//  LocationService+SearchCompleter.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.07.26.
//

import Foundation
import MapKit


extension LocationService: MKLocalSearchCompleterDelegate {
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results//.filter({ $0.subtitle == "" })
        self.status        = completer.results.isEmpty ? .noResults : .result
    }

    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.status = .error(error.localizedDescription)
    }
}
