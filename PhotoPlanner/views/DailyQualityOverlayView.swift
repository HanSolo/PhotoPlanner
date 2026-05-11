//
//  DailyQualityOverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation
import SwiftUI


struct DailyQualityOverlayView: View {
    let timeline: DailyQualityTimeline

    var body: some View {
        GeometryReader { geometry in
            DailyQualityView(timeline: timeline)
                .background(.black.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
                .frame(width: geometry.size.width - 100)
                .offset(x: 50, y: 100)
        }
    }

    private func gradeValue(_ grade: SunriseSunsetScore.Grade) -> Int {
        switch grade {
        case .poor:        return 0
        case .fair:        return 1
        case .good:        return 2
        case .great:       return 3
        case .spectacular: return 4
        }
    }
}
