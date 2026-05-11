//
//  SolarEvent.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation

struct SolarEvent {
    let time : Date
    let type : EventType
    
    enum EventType { case sunrise, sunset, goldenHour }
}
