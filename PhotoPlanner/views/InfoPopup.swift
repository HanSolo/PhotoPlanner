//
//  FloatingNotice.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 18.06.26.
//

import Foundation
import SwiftUI


struct InfoPopup: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding                            var showPopup   : Bool

    
    var body: some View {
        VStack (alignment: .center, spacing: 8) {
            Image(systemName: "document.on.document")
                .foregroundColor(.white)
                .font(Constants.REGULAR_FONT_20)
            Text("Copied")
                .foregroundColor(.white)
                .font(Constants.REGULAR_FONT_14)
        }
        .padding(10)
        .background(self.colorScheme == .dark ? .white.opacity(0.35) : .black.opacity(0.65))
        .cornerRadius(14)
        .transition(.opacity)
        .onAppear(perform: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                self.showPopup = false
            })
        })
    }
}
