//
//  MenuButton.swift
//  CDCircularMenu
//
//  Created by Christophe Dellac on 4/8/20.
//  Copyright © 2020 Christophe Dellac. All rights reserved.
//

import SwiftUI


struct MenuButton: View {
    @Environment(\.colorScheme) private var colorScheme
    var isOpen           : Bool
    let scaleEffectValue : CGFloat
    let menuButtonSize   : CGFloat
    
    
    var body: some View {
        return Image(systemName: "xmark.circle.fill" )
            .symbolRenderingMode(.hierarchical)
            .resizable()
            .scaledToFit()
            .frame(width: self.menuButtonSize, height: self.menuButtonSize)
            .foregroundStyle(self.isOpen ? .red : self.colorScheme == .dark ? .white : .gray)
            .rotationEffect(self.isOpen ? Angle(degrees: 0) : Angle(degrees: 45))
            .buttonStyle(.glass)
    }
}

struct MenuButton_Previews: PreviewProvider {
    static var previews: some View {
        MenuButton(isOpen: true, scaleEffectValue: 0.8, menuButtonSize: 50)
    }
}
