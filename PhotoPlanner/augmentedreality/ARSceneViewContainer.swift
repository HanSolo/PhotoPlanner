//
//  ARSceneViewContainer.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//


import SwiftUI
import ARKit
import SceneKit
import CoreLocation
internal import Combine


struct ARSceneViewContainer: UIViewRepresentable {
    let viewModel: ARViewModel

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView : ARSCNView = ARSCNView()
        sceneView.antialiasingMode             = .multisampling4X
        sceneView.automaticallyUpdatesLighting = false
        sceneView.rendersContinuously          = false // true might lead to flicker

        viewModel.setup(sceneView: sceneView)
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) { }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }
}
