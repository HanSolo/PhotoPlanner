//
//  MenuItem.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 27.05.26.
//

import Foundation
import SwiftUI


public struct MenuItem: Identifiable {
    public let id : Int
    let imageSFSymbol           : String?
    let foregroundSFSymbolColor : Color?
    let imageAsset              : String?
    let backgroundColor         : Color
    
    
    public init(id: Int, imageSFSymbol: String?, foregroundSFSymbolColor: Color?, imageAsset: String?, backgroundColor: Color) {
        self.id                      = id
        self.imageSFSymbol           = imageSFSymbol
        self.foregroundSFSymbolColor = foregroundSFSymbolColor
        self.imageAsset              = imageAsset
        self.backgroundColor         = backgroundColor
    }
}
