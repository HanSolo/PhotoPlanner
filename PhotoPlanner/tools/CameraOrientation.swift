//
//  CameraOrientation.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public enum CameraOrientation: String, CaseIterable {
    case landscape
    case portrait
    
    var name: String {
        switch self {
            case .landscape : return "Landscape"
            case .portrait  : return "Portrait"
        }
    }
    
    var icon: String {
        switch self {
            case .landscape : return "rectangle"
            case .portrait  :  return "rectangle.portrait"
        }
    }

    var jsonString: String {
        var text : String = "{"
        text += "\"cameraOrientation\":\"\(self.name)\""
        text += "}"
        return text
    }
}
