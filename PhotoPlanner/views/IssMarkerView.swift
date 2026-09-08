//
//  IssMarkerView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.09.26.
//

import Foundation
import SwiftUI


struct IssMarkerView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.25))
                .frame(width: 24, height: 24)
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
            Circle()
                .stroke(Color.cyan, lineWidth: 2)
                .frame(width: 12, height: 12)
        }
    }
}

