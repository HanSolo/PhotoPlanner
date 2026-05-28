//
//  RadialMenu.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 27.05.26.
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
                                    self.buttonClickCompletion(self.menuItems[index].id)
                                    self.isOpen.toggle()
                                }
                            } , label: {                                
                                MenuItemSymbol(menuItem: self.menuItems[index], menuItemSize: self.menuItemSize)
                                    .rotationEffect(isOpen ? .zero : .degrees(900))
                                    .frame(width: 44, height: 44)
                            })
                            .buttonStyle(.glass)
                            .frame(width: self.menuItemSize, height: self.menuItemSize)
                            .clipShape(Circle())
                            .offset(x: self.xOffset(index), y: self.yOffset(index))
                        }
                    }
                }
                .modifier(AnimationModifier(isOpen: self.isOpen, scaleEffectValue: self.scaleEffectValue))

                Button(action: {
                    withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                        self.isOpen.toggle()
                    }
                }, label: {
                    CenterButton(isOpen: self.isOpen, scaleEffectValue: self.scaleEffectValue, menuButtonSize: self.menuButtonSize)
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
        menuItem.imageName != nil
    }
        
    private func canDisplayImageAsset(_ menuItem: MenuItem) -> Bool {
        menuItem.isAsset != nil
    }
    
    private func clamp(value: Int, minValue: Int, maxValue: Int) -> Int {
        if value < minValue { return minValue }
        if value > maxValue { return maxValue }
        return value
    }
}
