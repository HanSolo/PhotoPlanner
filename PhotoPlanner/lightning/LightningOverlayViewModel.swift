//
//  LightningOverlay.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 10.08.26.
//

import Foundation
import SwiftUI
import MapKit
import UIKit



@Observable
class LightningOverlayViewModel {
    var strikes        : [LightningStrike]    = []
    var isVisible      : Bool                 = false
    var strikesVisible : Bool                 = false {
        didSet {
            self.isVisible = self.strikesVisible
        }
    }
    var visibleRegion  : MKCoordinateRegion?

    private let mqttClient     : BlitzortungMQTTClient     = BlitzortungMQTTClient()
    private let haptic         : UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private var lastHapticTime : Date                      = Date.distantPast
    private let hapticThrottle : Double                    = 0.1    // 100 ms minimum between vibrations
    private let maxStrikes     : Int                       = 500
    public  let maxAge         : Double                    = 300.0  // 5 minutes
    private let bufferKm       : Double                    = 50.0

    
    init(username: String, password: String) {
        haptic.prepare()
        mqttClient.onStrike = { [weak self] strike in
            DispatchQueue.main.async { self?.handleStrike(strike) }
        }
    }

    
    func show(region: MKCoordinateRegion) {
        visibleRegion  = region
        strikesVisible = true
        isVisible      = true
        mqttClient.connect(username: "", password: "", topics: [ "lightning/strikes" ])
    }

    func hide() {
        strikesVisible = false
        isVisible      = false
        mqttClient.disconnect()
    }

    func updateRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        pruneStrikesOutsideRegion(region)
    }

    func pruneOldStrikes() {
        let cutoff : Date = Date().addingTimeInterval(-self.maxAge)
        strikes.removeAll { $0.timestamp < cutoff }
    }

    private func handleStrike(_ strike: LightningStrike) {
        guard strikesVisible, let region = visibleRegion else { return }
        guard isWithinBuffer(strike, region: region) else { return }
        strikes.append(strike)
        if strikes.count > maxStrikes { strikes.removeFirst(strikes.count - maxStrikes) }
        triggerHaptic()
    }
    
    private func triggerHaptic() {
        let now : Date = Date()
        guard now.timeIntervalSince(lastHapticTime) >= hapticThrottle else { return }
        DispatchQueue.main.async { [weak self] in
            self?.haptic.impactOccurred()
        }
        lastHapticTime = now
    }

    private func isWithinBuffer(_ strike: LightningStrike, region: MKCoordinateRegion) -> Bool {
        let bufferLat : Double = bufferKm / 111.0
        let bufferLon : Double = bufferKm / (111.0 * cos(region.center.latitude * .pi / 180))
        let minLat    : Double = region.center.latitude  - region.span.latitudeDelta  / 2 - bufferLat
        let maxLat    : Double = region.center.latitude  + region.span.latitudeDelta  / 2 + bufferLat
        let minLon    : Double = region.center.longitude - region.span.longitudeDelta / 2 - bufferLon
        let maxLon    : Double = region.center.longitude + region.span.longitudeDelta / 2 + bufferLon
        return strike.latitude  >= minLat && strike.latitude <= maxLat && strike.longitude >= minLon && strike.longitude <= maxLon
    }

    private func pruneStrikesOutsideRegion(_ region: MKCoordinateRegion) {
        strikes = strikes.filter { isWithinBuffer($0, region: region) }
    }
}
