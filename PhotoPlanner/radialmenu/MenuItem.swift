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
    let imageName   : String?
    let symbolColor : Color?
    let isAsset     : Bool?
    
    
    public init(id: Int, imageName: String?, symbolColor: Color? = Color.white, isAsset: Bool? = false) {
        self.id          = id
        self.imageName   = imageName
        self.symbolColor = symbolColor
        self.isAsset     = isAsset
    }
}
