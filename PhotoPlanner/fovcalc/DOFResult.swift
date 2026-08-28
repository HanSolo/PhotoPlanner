//
//  DOFResult.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.08.26.
//

import Foundation
import SwiftUI


struct DOFResult {
    let nearLimit          : Double   // metres
    let farLimit           : Double   // metres — Double.infinity when beyond hyperfocal
    let hyperfocal         : Double   // metres
    let frameWidthAtFocus  : Double   // metres
    let frameHeightAtFocus : Double   // metres
    let cocMm              : Double   // circle of confusion in mm
}
