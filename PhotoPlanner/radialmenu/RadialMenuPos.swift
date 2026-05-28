//
//  RadialMenuPos.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 27.05.26.
//

import Foundation


public enum RadialMenuPos {
    case center
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
    
    
    var range : CGFloat {
        switch self {
            case .center      : return Constants.fullCircle
            case .topLeft     : return Constants.quarterCircle
            case .top         : return Constants.halfCircle
            case .topRight    : return Constants.quarterCircle
            case .right       : return Constants.halfCircle
            case .bottomRight : return Constants.quarterCircle
            case .bottom      : return Constants.halfCircle
            case .bottomLeft  : return Constants.quarterCircle
            case .left        : return Constants.halfCircle
        }
    }
    
    var offset : CGFloat {
        switch self {
            case .center      : return -Constants.quarterCircle
            case .topLeft     : return 0.0
            case .top         : return 0.0
            case .topRight    : return Constants.quarterCircle
            case .right       : return Constants.halfCircle
            case .bottomRight : return Constants.halfCircle
            case .bottom      : return Constants.halfCircle
            case .bottomLeft  : return -Constants.quarterCircle
            case .left        : return Constants.quarterCircle
        }
    }
}
