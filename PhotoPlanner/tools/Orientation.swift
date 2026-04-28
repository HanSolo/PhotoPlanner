//
//  Orientation.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public enum Orientation: String {
    case landscape
    case portrait
    
    var name: String {
        switch self {
            case .landscape: return "Landscape"
            case .portrait : return "Portrait"
        }
    }

    var jsonString: String {
        var text : String = "{"
        text += "\"orientation\":\"\(self)\""
        text += "}"
        return text
    }
}
