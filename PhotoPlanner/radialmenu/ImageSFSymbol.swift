//
//  ImageSFSymbol.swift
//  CDCircularMenu
//
//  Created by Christophe Dellac on 4/8/20.
//  Copyright © 2020 Christophe Dellac. All rights reserved.
//

import SwiftUI

struct ImageSFSymbol: View {
    let menuItem     : MenuItem
    let menuItemSize : CGFloat
    
    
    var body: some View {
        Image(systemName: self.menuItem.imageSFSymbol!)
            //.resizable()
            //.scaledToFit()
            //.frame(width: self.menuButtonSize, height: self.menuButtonSize)
            //.foregroundStyle(.white)
            .background(Circle().fill(self.menuItem.backgroundColor).frame(width: self.menuItemSize, height: self.menuItemSize))
            //.clipShape(Circle())
            .frame(maxWidth: self.menuItemSize, maxHeight: self.menuItemSize)
            //.padding(7)
            .backgroundStyle(.thinMaterial)
            .symbolRenderingMode(.hierarchical)
            //.resizable()
            //.scaledToFit()
            //.foregroundStyle(.white)            
    }
}

struct ImageSFSymbol_Previews: PreviewProvider {
    static var previews: some View {
        ImageSFSymbol(menuItem: MenuItem(id: 0, imageSFSymbol: "tortoise", foregroundSFSymbolColor: Color.white, imageAsset: nil, backgroundColor: .blue), menuItemSize: 44)
    }
}
