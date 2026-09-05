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
    var strikes           : [LightningStrike]    = []
    var isVisible         : Bool                 = false
    var strikesVisible    : Bool                 = false {
        didSet {
            self.isVisible = self.strikesVisible
        }
    }
    var visibleRegion     : MKCoordinateRegion? {
        didSet { regionVersion += 1 }
    }
    
    private(set) var regionVersion : Int          = 0
    var stormCells        : [Cell]               = []
    var stormCellsVisible : Bool                 = Properties.instance.stormCellsVisible!

    private let mqttClient          : BlitzortungMQTTClient     = BlitzortungMQTTClient()
    private let haptic              : UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private var lastHapticTime      : Date                      = Date.distantPast
    private let hapticThrottle      : Double                    = 0.1    // 100 ms minimum between vibrations
    private let maxStrikes          : Int                       = 500
    public  let maxAge              : Double                    = 300.0  // 5 minutes
    private let bufferKm            : Double                    = 50.0
    private var isFetchingCells     : Bool                      = false
    private var lastStormCellUpdate : Date                      = Date.distantPast

    
    init(username: String, password: String) {
        haptic.prepare()
        mqttClient.onStrike = { [weak self] strike in
            DispatchQueue.main.async { self?.handleStrike(strike) }
        }
        if self.stormCellsVisible {
            Task {
                await self.fetchStormCells()
            }
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
        filterForStrikesInRegion(region)
        filterForStormCellsInRegion(region)
    }

    // Called once per second by a low-frequency TimelineView schedule in the
    // view, NOT per animation frame. Pruning is cheap but was previously
    // invoked up to 120x/sec tied to the lightning-flash timeline, which is
    // unnecessary, strikes only need pruning at roughly 1s granularity given
    // a 300s maxAge, and was contributing to the "multiple updates per
    // frame" warning by mutating an @Observable array inside a hot per-frame
    // callback.
    func pruneOldStrikes() {
        let cutoff : Date = Date().addingTimeInterval(-self.maxAge)
        strikes.removeAll { $0.timestamp < cutoff }
        
        if self.stormCellsVisible && self.lastStormCellUpdate.timeIntervalSinceNow < -600 {
            Task {
                await fetchStormCells()
            }
        }
        
    }
    
    func fetchStormCells() async -> Void {
        if self.isFetchingCells { return }
        isFetchingCells = true
        lastStormCellUpdate = Date()
        let fetched = await RestController.fetchStormCells()
        // Single assignment instead of removeAll() + += so stormCells only
        // publishes one change, not two, per fetch.
        self.stormCells = fetched
        isFetchingCells = false
    }

    private func handleStrike(_ strike: LightningStrike) {
        guard strikesVisible, let region = visibleRegion else { return }
        guard isWithinStrikeBuffer(strike, region: region) else { return }
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

    
    private func isWithinStrikeBuffer(_ strike: LightningStrike, region: MKCoordinateRegion) -> Bool {
        let bufferLat : Double = bufferKm / 111.0
        let bufferLon : Double = bufferKm / (111.0 * cos(region.center.latitude * .pi / 180))
        let minLat    : Double = region.center.latitude  - region.span.latitudeDelta  / 2 - bufferLat
        let maxLat    : Double = region.center.latitude  + region.span.latitudeDelta  / 2 + bufferLat
        let minLon    : Double = region.center.longitude - region.span.longitudeDelta / 2 - bufferLon
        let maxLon    : Double = region.center.longitude + region.span.longitudeDelta / 2 + bufferLon
        return strike.latitude  >= minLat && strike.latitude <= maxLat && strike.longitude >= minLon && strike.longitude <= maxLon
    }
    
    private func filterForStrikesInRegion(_ region: MKCoordinateRegion) {
        strikes = strikes.filter { isWithinStrikeBuffer($0, region: region) }
    }
    
    
    private func isWithinStormCellBuffer(_ cell: Cell, region: MKCoordinateRegion) -> Bool {
        let bufferLat : Double = bufferKm / 111.0
        let bufferLon : Double = bufferKm / (111.0 * cos(region.center.latitude * .pi / 180))
        let minLat    : Double = region.center.latitude  - region.span.latitudeDelta  / 2 - bufferLat
        let maxLat    : Double = region.center.latitude  + region.span.latitudeDelta  / 2 + bufferLat
        let minLon    : Double = region.center.longitude - region.span.longitudeDelta / 2 - bufferLon
        let maxLon    : Double = region.center.longitude + region.span.longitudeDelta / 2 + bufferLon
        return cell.lat!  >= minLat && cell.lat! <= maxLat && cell.lon! >= minLon && cell.lon! <= maxLon
    }
    
    private func filterForStormCellsInRegion(_ region: MKCoordinateRegion) {
        stormCells = stormCells.filter { isWithinStormCellBuffer($0, region: region) }
    }
}
