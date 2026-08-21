//
//  AlertsPopoverView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.08.26.
//

import Foundation
import SwiftUI


struct AlertsPopoverView: View {
    let alerts : [WeatherAlert]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(alerts) { alert in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: alert.icon)
                            .foregroundStyle(alert.severity.color)
                            .font(.system(size: 16))

                        Text(alert.event)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(alert.severity.color)

                        Spacer()

                        Text(alert.severity.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(alert.severity.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(alert.severity.color.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Text(alert.headline)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(alert.expiryLabel)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !alert.sender.isEmpty {
                            Text(alert.sender)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .navigationTitle("Weather Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
