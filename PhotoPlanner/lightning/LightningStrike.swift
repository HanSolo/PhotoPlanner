//
//  LightningStrike.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 13.08.26.
//
import Foundation
import SwiftUI


struct LightningStrike: Identifiable, Sendable {
    let id          : UUID = UUID()
    let latitude    : Double
    let longitude   : Double
    let timestamp   : Date
    let nanoseconds : Int64
    let polarity    : Int // -1, 0, +1

    func age(at time: Date) -> Double {
        time.timeIntervalSince(timestamp)
    }

    func opacity(at time: Date) -> Double {
        let age       : Double = self.age(at: time)
        let fadeStart : Double = 20.0
        let maxAge    : Double = 150.0
        if age < fadeStart { return 1.0 }
        return max(0, 1.0 - (age - fadeStart) / (maxAge - fadeStart))
    }

    func color(at time: Date) -> Color {
        let age : Double = self.age(at: time)
        switch age {
            case ..<10    : return .white
            case 10..<60  : return Color(red: 1.0, green: 0.95, blue: 0.5)
            case 60..<120 : return Color(red: 1.0, green: 0.85, blue: 0.2)
            default       : return Color(red: 1.0, green: 0.65, blue: 0.1)
        }
    }

    enum AnimationPhase {
        case expanding
        case contracting
        case persistent
    }

    func phase(at time: Date) -> AnimationPhase {
        switch self.age(at: time) {
            case ..<0.03     : return .expanding    // flash         : 0...0.03s
            case 0.03..<0.22 : return .contracting  // shrink to dot : 0.03...0.22s
            default          : return .persistent   // dot           : 0.22s...2.5min
        }
    }
}
