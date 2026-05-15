//
//  PhotoPlannerApp.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.04.26.
//

import SwiftUI
import SwiftData

@main
struct PhotoPlannerApp: App {
    let model : PhotoPlannerModel = PhotoPlannerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(self.model)
        }
        .modelContainer(for: [Camera.self, Lens.self, PhotoShoot.self])
    }
}
