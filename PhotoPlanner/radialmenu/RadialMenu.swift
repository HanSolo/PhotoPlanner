//
//  CircularMenu.swift
//  CDCircularMenu
//
//  Created by Christophe Dellac on 4/8/20.
//  Copyright © 2020 Christophe Dellac. All rights reserved.
//

import SwiftUI

public struct RadialMenu: View {    
    @State                      private var isOpen : Bool = false
        
    private let scaleEffectValue : CGFloat = 0.6
        
    let menuItems                : [MenuItem]
    let menuPos                  : RadialMenuPos
    let menuRadius               : CGFloat
    let menuButtonSize           : CGFloat
    let menuItemSize             : CGFloat
    let buttonClickCompletion    : (Int) -> Void
    
    
    public init(menuItems: [MenuItem], menuPos: RadialMenuPos = RadialMenuPos.center, menuRadius: CGFloat, menuButtonSize: CGFloat, menuItemSize: CGFloat, buttonClickCompletion: @escaping (Int) -> Void) {
        self.menuItems             = menuItems
        self.menuPos               = menuPos
        self.menuRadius            = menuRadius
        self.menuButtonSize        = menuButtonSize
        self.menuItemSize          = menuItemSize
        self.buttonClickCompletion = buttonClickCompletion
    }
    
    
    public var body: some View {
        VStack {
            ZStack {
                VStack {
                    ZStack {
                        ForEach (0 ..< menuItems.count, id: \.self) { index in
                            Button(action: {
                                withAnimation {
                                    debugPrint("[CDCircularMenu] Button id[\(self.menuItems[index].id)] has been clicked.")
                                    self.buttonClickCompletion(self.menuItems[index].id)
                                    self.isOpen.toggle()
                                }
                            } , label: {
                                if self.canDisplaySFSymbol(self.menuItems[index]) {
                                    ImageSFSymbol(menuItem: self.menuItems[index], menuItemSize: self.menuItemSize)
                                        .rotationEffect(isOpen ? .zero : .degrees(900))
                                        //.animation(.easeOut(duration: 0.5).delay(0.0), value: 1)
                                } else if self.canDisplayImageAsset(self.menuItems[index]) {
                                    ImageAsset(menuItem: self.menuItems[index], menuItemSize: self.menuItemSize)
                                        .rotationEffect(isOpen ? .zero : .degrees(900))
                                        //.animation(.easeOut(duration: 0.5).delay(0.0), value: 1)
                                }
                            })
                            .buttonStyle(.plain)
                            .offset(x: self.xOffset(index), y: self.yOffset(index))
                        }
                    }
                }
                .modifier(AnimationModifier(isOpen: self.isOpen, scaleEffectValue: self.scaleEffectValue))

                Button(action: {
                    withAnimation {
                        self.isOpen.toggle()
                    }
                }, label: {
                    MenuButton(isOpen: self.isOpen, scaleEffectValue: self.scaleEffectValue, menuButtonSize: self.menuButtonSize)
                })
            }
        }
    }
    
        
    private func xOffset(_ index: Int) -> CGFloat {
        let slice : CGFloat = CGFloat(self.menuPos.range / CGFloat(self.menuItems.count - 1))
        return menuRadius * cos(slice * CGFloat(index) + self.menuPos.offset)
    }
    
    private func yOffset(_ index: Int) -> CGFloat {
        let slice : CGFloat = CGFloat(self.menuPos.range / CGFloat(self.menuItems.count - 1))
        return menuRadius * sin(slice * CGFloat(index) + self.menuPos.offset)
    }
    
    private func canDisplaySFSymbol(_ menuItem: MenuItem) -> Bool {
        menuItem.imageSFSymbol != nil
    }
        
    private func canDisplayImageAsset(_ menuItem: MenuItem) -> Bool {
        menuItem.imageAsset != nil
    }
    
    private func clamp(value: Int, minValue: Int, maxValue: Int) -> Int {
        if value < minValue { return minValue }
        if value > maxValue { return maxValue }
        return value
    }
}


#if DEBUG
struct CircularMenu_Previews: PreviewProvider {
    
    static func buttonClickHandler(index: Int) {
        
    }
    
    static var previews: some View {
        RadialMenu(menuItems: [
            MenuItem(id: 0, imageSFSymbol: "tortoise", foregroundSFSymbolColor: Color.white, imageAsset: nil,      backgroundColor: .blue),
            MenuItem(id: 1, imageSFSymbol: "bolt",     foregroundSFSymbolColor: Color.white, imageAsset: nil,      backgroundColor: .yellow),
            MenuItem(id: 2, imageSFSymbol: nil,        foregroundSFSymbolColor: nil,         imageAsset: "forest", backgroundColor: .orange),
            MenuItem(id: 3, imageSFSymbol: "hare",     foregroundSFSymbolColor: Color.white, imageAsset: nil,      backgroundColor: .green),
            MenuItem(id: 4, imageSFSymbol: "flame",    foregroundSFSymbolColor: Color.white, imageAsset: nil,      backgroundColor: .red),
        ], menuRadius: 90, menuButtonSize: 44, menuItemSize: 44, buttonClickCompletion: CircularMenu_Previews.buttonClickHandler)
    }
}
#endif
