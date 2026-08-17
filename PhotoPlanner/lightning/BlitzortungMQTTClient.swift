//
//  BlitzortungMQTTClient.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 17.08.26.
//

import Foundation
import CocoaMQTT


class BlitzortungMQTTClient: CocoaMQTTDelegate {
    private      var mqtt          : CocoaMQTT?
    private      var currentTopics : Set<String> = []
    private      let clientID      : String      = "PhotoPlanner_\(UUID().uuidString.prefix(8))"
    private(set) var isConnected   : Bool        = false

    var onStrike: ((LightningStrike) -> Void)?


    func connect(username: String, password: String, topics: [String]) {
        disconnect()

        let client                       = CocoaMQTT(clientID: clientID, host: "hansolo.eu", port: 1883)
        client.username                  = username
        client.password                  = password
        client.keepAlive                 = 60
        client.cleanSession              = true
        client.autoReconnect             = true
        client.autoReconnectTimeInterval = 5
        client.delegate                  = self

        self.mqtt          = client
        self.currentTopics = Set(topics)
        _ = client.connect()
    }

    func updateTopics(_ newTopics: [String]) {
        guard isConnected, let mqtt else { return }
        let newSet        = Set(newTopics)
        let toUnsubscribe = Array(currentTopics.subtracting(newSet))
        let toSubscribe   = Array(newSet.subtracting(currentTopics))
        if !toUnsubscribe.isEmpty { mqtt.unsubscribe(toUnsubscribe) }
        if !toSubscribe.isEmpty   { mqtt.subscribe(toSubscribe.map { ($0, CocoaMQTTQoS.qos0) }) }
        currentTopics = newSet
    }

    func disconnect() {
        mqtt?.disconnect()
        mqtt          = nil
        isConnected   = false
        currentTopics = []
    }

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        guard ack == .accept else { return }
        isConnected = true
        if !currentTopics.isEmpty {
            mqtt.subscribe(currentTopics.map { ($0, CocoaMQTTQoS.qos0) })
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        guard let payload = message.string,
              let data    = payload.data(using: .utf8),
              let strike  = try? JSONDecoder().decode(Strike.self, from: data)
        else { return }

        let lightningStrike = LightningStrike(latitude: strike.lat ?? 0.0, longitude: strike.lon ?? 0.0, timestamp: Date(timeIntervalSince1970: Double(strike.time ?? 0) / 1_000_000_000), nanoseconds: Int64(strike.time ?? 0), polarity: strike.pol ?? 0)
        onStrike?(lightningStrike)
    }

    func mqtt(_ mqtt: CocoaMQTT, didDisconnectWithError err: Error?) { isConnected = false }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) { isConnected = false }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}

    func mqttDidPing(_ mqtt: CocoaMQTT) {}

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
}
