//
//  StormCellResponse.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.09.26.
//

import Foundation


struct StormCellResponse: Decodable {
    let type     : String
    let features : [StormCellFeature]
}
