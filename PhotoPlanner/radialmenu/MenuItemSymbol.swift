//
//  MenuItemSymbol.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 27.05.26.
//

import SwiftUI

struct MenuItemSymbol: View {
    let menuItem     : MenuItem
    let menuItemSize : CGFloat
    
    
    var body: some View {
        if self.menuItem.isAsset ?? false {
            Image(self.menuItem.imageName!)
                .resizable()
                .frame(width: self.menuItemSize * 0.5, height: self.menuItemSize * 0.5)
        } else {
            Image(systemName: self.menuItem.imageName!)
                .frame(width: self.menuItemSize, height: self.menuItemSize)
        }
    }
}
