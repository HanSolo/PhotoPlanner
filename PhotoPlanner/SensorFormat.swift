//
//  SensorFormat.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import Foundation


public enum SensorFormat: String, Equatable, CaseIterable {
    case mediumFormat
    case fullFormat
    case apsh
    case apsc
    case apscCanon
    case microFourThirds
    
    
    var name: String {
        switch self {
            case .mediumFormat    : return "Medium Format"
            case .fullFormat      : return "Full Format"
            case .apsh            : return "APS-H"
            case .apsc            : return "APS-C"
            case .apscCanon       : return "APS-C Canon"
            case .microFourThirds : return "Micro 4/3"
        }
    }
    
    var id: Int  {
        switch self {
            case .mediumFormat    : return 0
            case .fullFormat      : return 1
            case .apsh            : return 2
            case .apsc            : return 3
            case .apscCanon       : return 4
            case .microFourThirds : return 5
        }
    }
    
    var code: String {
        switch self {
            case .mediumFormat    : return "mediumFormat"
            case .fullFormat      : return "fullFormat"
            case .apsh            : return "apsh"
            case .apsc            : return "apsc"
            case .apscCanon       : return "apscCanon"
            case .microFourThirds : return "microFourThirds"
        }
    }
    
    var description: String {
        return self.name + " [\(self.width)mm x \(self.height)mm]"
    }
    
    var width: Double {
        switch self {
            case .mediumFormat    : return 53.7
            case .fullFormat      : return 36.0
            case .apsh            : return 27.9
            case .apsc            : return 23.6
            case .apscCanon       : return 22.2
            case .microFourThirds : return 17.3
        }
    }
    
    var height: Double {
        switch self {
            case .mediumFormat    : return 40.2
            case .fullFormat      : return 23.9
            case .apsh            : return 18.6
            case .apsc            : return 15.8
            case .apscCanon       : return 14.8
            case .microFourThirds : return 13.0
        }
    }
    
    var cropFactor: Double {
        switch self {
            case .mediumFormat    : return 0.64
            case .fullFormat      : return 1.0
            case .apsh            : return 1.29
            case .apsc            : return 1.52
            case .apscCanon       : return 1.6
            case .microFourThirds : return 2.0
        }
    }
    
    var jsonString: String {
        var text: String = "{"
        text += "\"name\":\"\(self)\","
        text += "\"width\":\"\(width)\","
        text += "\"height\":\"\(height)\","
        text += "\"crop\":\"\(cropFactor)\""
        text += "}"
        return text
    }
    
    
    public static func ==(lhs: SensorFormat, rhs: SensorFormat) -> Bool {
        return lhs.name       == rhs.name &&
               lhs.width      == rhs.width &&
               lhs.height     == rhs.height &&
               lhs.cropFactor == rhs.cropFactor
    }
    
    public static func fromCode(_ code: String) -> SensorFormat? {
        return SensorFormat.allCases.first(where: { $0.code == code })
    }
    
    public static func fromId(_ id: Int) -> SensorFormat? {
        return SensorFormat.allCases.first(where: { $0.id == id })
    }
}
