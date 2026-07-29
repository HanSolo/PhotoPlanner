//
//  SearchView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.07.26.
//

import Foundation
import SwiftUI
import MapKit


struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject                 var locationService : LocationService
    
    var functio : (_ coordinates: CLLocationCoordinate2D) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text("Location Search")
                        .font(Constants.REGULAR_FONT_18)
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                }
                .buttonStyle(.glass)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                Form {
                    Section(header: Text("")) {
                        ZStack(alignment: .trailing) {
                            TextField("Search", text: $locationService.queryFragment)
                                .disableAutocorrection(true)
                                .font(Constants.REGULAR_FONT_20)
                            if locationService.status == .isSearching {
                                Image(systemName: "clock")
                            }
                        }
                    }
                    Section {
                        List {
                            ForEach(locationService.searchResults, id: \.self) { completionResult in
                                let mapItem = completionResult.value(forKey: "_mapItem") as? MKMapItem
                                if mapItem != nil {
                                    let address  : Address                = Address(mapItem: mapItem!)
                                    let location : CLLocationCoordinate2D = address.location()
                                    
                                    HStack(spacing: .some(Constants.IS_IPAD ? 30 : 15)) {
                                        Button {
                                        } label: {
                                            Image(systemName: "map.circle.fill")
                                                .background(.clear)
                                                .font(.system(size: 22))
                                        }
                                        .highPriorityGesture(TapGesture().onEnded {
                                            functio(location)
                                            dismiss()
                                        })
                                        Text("\(Helper.formatAddress(name: completionResult.title, address: address))")
                                            .font(Constants.REGULAR_FONT_14)
                                    }
                                    
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .backgroundStyle(.thinMaterial)
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).opacity(0.01))
        .backgroundStyle(.thinMaterial)
        .presentationDragIndicator(.visible)
    }
}
