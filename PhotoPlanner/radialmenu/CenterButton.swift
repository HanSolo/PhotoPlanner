//
//  CenterButton.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 27.05.26.
//

import SwiftUI


struct CenterButton: View {
    @Environment(\.colorScheme) private var colorScheme
    var isOpen           : Bool
    let scaleEffectValue : CGFloat
    let menuButtonSize   : CGFloat
    
    
    var body: some View {
        return Image(systemName: "xmark.circle.fill" )
            //.symbolRenderingMode(.hierarchical)
            .resizable()
            .scaledToFit()
            .frame(width: self.menuButtonSize, height: self.menuButtonSize)
            .foregroundStyle(self.isOpen ? .red : self.colorScheme == .dark ? .white : .gray)
            .rotationEffect(self.isOpen ? Angle(degrees: 0) : Angle(degrees: 45))
            .buttonStyle(.glass)            
            .clipShape(Circle())
    }
}

struct MenuButton_Previews: PreviewProvider {
    static var previews: some View {
        CenterButton(isOpen: true, scaleEffectValue: 0.8, menuButtonSize: 50)
    }
}
