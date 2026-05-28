//
//  AnimationModifier.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.05.26.
//

import SwiftUI


struct AnimationModifier: ViewModifier {
    let isOpen           : Bool
    let scaleEffectValue : CGFloat
    
    
    func body(content: Content) -> some View {
        content
            .opacity(self.isOpen ? 1 : 0)
            .scaleEffect(self.isOpen ? 1 : 0)
    }
}
