//
//  LibreWxrColorScheme.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 18.08.26.
//

import Foundation


enum LibreWxrColorScheme: Int, CaseIterable, Identifiable {
    case blackAndWhite    = 0
    case rainviewerOrig   = 1
    case universalBlue    = 2
    case titan            = 3
    case theWeatherChan   = 4
    case meteored         = 5
    case nexradLevel3     = 6
    case rainbow          = 7
    case darkSky          = 8
    case datameteoValerio = 9
    case viperHD          = 10
    case mrmsCref         = 11

    var id   : Int    { rawValue }
    var name : String {
        switch self {
            case .blackAndWhite    : return "Black & White"
            case .rainviewerOrig   : return "Rainviewer Original"
            case .universalBlue    : return "Universal Blue"
            case .titan            : return "TITAN"
            case .theWeatherChan   : return "The Weather Channel"
            case .meteored         : return "Meteored"
            case .nexradLevel3     : return "NEXRAD Level III"
            case .rainbow          : return "Rainbow"
            case .darkSky          : return "Dark Sky"
            case .datameteoValerio : return "Datameteo Valerio"
            case .viperHD          : return "Viper HD"
            case .mrmsCref         : return "MRMS CREF"
        }
    }
}
