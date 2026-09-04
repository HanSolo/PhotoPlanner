//
//  StormCellError.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.09.26.
//

import Foundation


enum StormCellError: Error {
    case badURL
    case detectionDisabled  // 503
    case httpError(Int)
}
