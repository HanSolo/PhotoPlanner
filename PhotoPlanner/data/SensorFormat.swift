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
    case one
    case twoThirds
    case oneThreeDotTwo
    
    
    
    var name: String {
        switch self {
            case .mediumFormat    : return "Medium Format"
            case .fullFormat      : return "Full Format"
            case .apsh            : return "APS-H"
            case .apsc            : return "APS-C"
            case .apscCanon       : return "APS-C Canon"
            case .microFourThirds : return "Micro 4/3"
            case .one             : return "1\""
            case .twoThirds       : return "2/3\""
            case .oneThreeDotTwo  : return "1/3.2\""
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
            case .one             : return 6
            case .twoThirds       : return 7
            case .oneThreeDotTwo  : return 8
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
            case .one             : return "oneInch"
            case .twoThirds       : return "twoThirds"
            case .oneThreeDotTwo  : return "oneThreeDotTwo"
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
            case .one             : return 13.2
            case .twoThirds       : return 8.8
            case .oneThreeDotTwo  : return 4.5
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
            case .one             : return 8.8
            case .twoThirds       : return 6.6
            case .oneThreeDotTwo  : return 3.4
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
            case .one             : return 2.7
            case .twoThirds       : return 5.62
            case .oneThreeDotTwo  : return 7.61
        }
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
