//
//  Orientation.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public enum CameraOrientation: String {
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
        text += "\"cameraOrientation\":\"\(self.name)\""
        text += "}"
        return text
    }
}
