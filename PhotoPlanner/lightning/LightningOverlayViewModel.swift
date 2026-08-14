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
    var strikes       : [LightningStrike]    = []
    var isVisible     : Bool                 = false
    var isLoading     : Bool                 = false
    var visibleRegion : MKCoordinateRegion?

    private let client              : BlitzortungRESTClient
    private let haptic              : UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private var lastHapticTime      : Date                      = Date.distantPast
    private let hapticThrottle      : Double                    = 0.1    // 100 ms minimum between vibrations
    private let maxStrikes          : Int                       = 500
    private let maxAge              : Double                    = 150.0  // 2.5 minutes
    private let bufferKm            : Double                    = 50.0
    private var lastStrikeTimestamp : Int64 = 0
    private var pollingTask         : Task<Void, Never>?
    private var activeInterval      : TimeInterval {
        let recentCutoff     : Date = Date().addingTimeInterval(-60) // strikes in last 60s
        let hasRecentStrikes : Bool = strikes.contains { $0.timestamp > recentCutoff }
        return hasRecentStrikes ? 20 : 45   // 20s active, 45s quiet
    }

    
    init(username: String, password: String) {
        self.client = BlitzortungRESTClient(username: username, password: password)
        haptic.prepare()
    }

    
    func show(region: MKCoordinateRegion) {
        visibleRegion = region
        isVisible  = true
        startPolling()
    }

    func hide() {
        isVisible = false
        stopPolling()
    }

    func updateRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        pruneStrikesOutsideRegion(region)
    }

    func pruneOldStrikes() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        strikes.removeAll { $0.timestamp < cutoff }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            // Initial fetch — get last 200 strikes in region
            await self.poll()
            // Subsequent polls at adaptive interval
            while !Task.isCancelled && self.isVisible {
                let interval = self.activeInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled { await self.poll() }
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func poll() async {
        guard let region = visibleRegion else { return }
        let box    = boundingBox(for: region)
        let cursor = lastStrikeTimestamp
        isLoading  = true

        let newStrikes = await client.fetchStrikes(north: box.north, south: box.south, east: box.east, west: box.west, afterTimestamp: cursor, maxCount: cursor == 0 ? 200 : 500)
            
        // Fix for REST polling delay
        await MainActor.run { [weak self] in
            guard let self else { return }
            isLoading = false
            guard !newStrikes.isEmpty else { return }

            if let newest = newStrikes.map({ $0.nanoseconds }).max() {
                lastStrikeTimestamp = newest
            }

            let now         = Date()
            let isFirstPoll = self.strikes.isEmpty
            let filtered    = newStrikes.filter { self.isWithinBuffer($0, region: region) }
            for (index, strike) in filtered.enumerated() {
                if isFirstPoll || index >= 10 {
                    self.strikes.append(strike)
                } else {
                    let baseDelay          : Double = Double(index) * 0.1
                    let randomDelay        : Double = baseDelay + Double.random(in: -0.04...0.04)
                    let finalDelay         : Double = max(0, randomDelay)
                    let staggeredTimestamp : Date   = now.addingTimeInterval(finalDelay)
                    self.strikes.append(LightningStrike(latitude: strike.latitude, longitude: strike.longitude, timestamp: staggeredTimestamp, nanoseconds: strike.nanoseconds, polarity: strike.polarity))
                    DispatchQueue.main.asyncAfter(deadline: .now() + finalDelay) { [weak self] in
                        self?.haptic.impactOccurred()
                    }                    
                }
            }
            if self.strikes.count > self.maxStrikes {
                self.strikes.removeFirst(self.strikes.count - self.maxStrikes)
            }
        }
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

    private func boundingBox(for region: MKCoordinateRegion) -> (north: Double, south: Double, east: Double, west: Double) {
        let bufferLat : Double = bufferKm / 111.0
        let bufferLon : Double = bufferKm / (111.0 * cos(region.center.latitude * .pi / 180))
        return (
            north: region.center.latitude  + region.span.latitudeDelta  / 2 + bufferLat,
            south: region.center.latitude  - region.span.latitudeDelta  / 2 - bufferLat,
            east:  region.center.longitude + region.span.longitudeDelta / 2 + bufferLon,
            west:  region.center.longitude - region.span.longitudeDelta / 2 - bufferLon
        )
    }
}
