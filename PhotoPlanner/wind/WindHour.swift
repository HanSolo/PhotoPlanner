//
//  WindHour.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.08.26.
//
import Foundation


struct WindHour: Sendable {
    let time         : Date
    let speedMs      : Double // [m/s]
    let directionDeg : Double // meteorological degrees (FROM), we convert to TO
}
