//
//  Color+Web.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.09.26.
//

import Foundation
import SwiftUI


extension Color {
    init(hex: String) {
        var hexString : String
        if hex.hasPrefix("#") {
            let index = hex.index(hex.startIndex, offsetBy: 1)
            hexString = String(hex.suffix(from: index))
        } else {
            hexString = hex
        }
        
        
        hexString = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
            case 3: // RGB (12-bit)
                (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: // RGB (24-bit)
                (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: // ARGB (32-bit)
                (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red    : Double(r) / 255,
            green  : Double(g) / 255,
            blue   : Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
