//
//  SunQualityButton.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 11.05.26.
//

import Foundation
import SwiftUI


struct SunQualityButton: View {
    @Bindable var vm: SunQualityViewModel
    let onTap: () -> Void

    var body: some View {
        Button {
            guard !vm.isLoading else { return }
            if vm.dailyTimeline != nil {
                withAnimation { vm.dismiss() }
            } else {
                onTap()
            }
        } label: {
            Image(systemName: vm.dailyTimeline != nil ? "sun.max.fill" : "sun.horizon")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(vm.dailyTimeline != nil ? .orange : .primary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(vm.isLoading)
    }
}
