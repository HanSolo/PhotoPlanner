//
//  View+TapGestureBugFix.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation
import SwiftUI


extension View {
    func onTapGestureBugFix(_ action: @escaping (GestureType, CGPoint?) -> Void) -> some View {
        modifier(TapGestureModifier(action: action))
    }
}

enum GestureType {
    case Tap
    case Drag
}

struct TapGestureModifier: ViewModifier {
    var action: ((_ type: GestureType, _ loc: CGPoint?) -> Void)
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.simultaneousGesture(SpatialEventGesture().onChanged { events in
                action(.Drag, events.first?.location)
        }).simultaneousGesture(SpatialTapGesture().onEnded { event in
            action(.Tap, event.location)
        })
    }
    else {
        content.onTapGesture { location in
            action(.Tap, location)
        }
    }
   }
}
