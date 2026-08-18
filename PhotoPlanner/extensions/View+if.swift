//
//  View+if.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 18.08.26.
//

import Foundation
import SwiftUI


extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) }
        else         { self }
    }
}
