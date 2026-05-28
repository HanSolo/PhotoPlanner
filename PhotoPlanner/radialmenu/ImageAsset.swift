//
//  ImageAsset.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 27.05.26.
//

import SwiftUI

struct ImageAsset: View {
    let menuItem     : MenuItem
    let menuItemSize : CGFloat
    
    
    var body: some View {
        Image(self.menuItem.imageAsset!)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: self.menuItemSize, maxHeight: self.menuItemSize)
            .foregroundColor(.white)
            .backgroundStyle(.thinMaterial)
            .background(
                Circle().fill(self.menuItem.backgroundColor)
                    .frame(width: self.menuItemSize, height: self.menuItemSize))
    }
}

struct ImageAsset_Previews: PreviewProvider {
    static var previews: some View {
        ImageAsset(menuItem: MenuItem(id: 0, imageSFSymbol: nil, foregroundSFSymbolColor: nil, imageAsset: "forest", backgroundColor: .orange), menuItemSize: 44)
    }
}
