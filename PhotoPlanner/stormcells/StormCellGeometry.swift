//
//  StormCellGeometry.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.09.26.
//

import Foundation


struct StormCellGeometry: Decodable {
    let type        : String
    let coordinates : [Double]
}
