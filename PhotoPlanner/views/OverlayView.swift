//
//  OverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 30.04.26.
//

import SwiftUI

struct OverlayView: View {
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(PhotoPlannerModel.self) private var model
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { ctx, size in
                    let fovData : FoVData? = self.model.fovData
                    if nil != fovData {
                        let darkMode          : Bool                    = self.colorScheme == .dark
                        let width             : Double                  = size.width
                        let height            : Double                  = size.height
                        let offsetX           : Double                  = 100.0
                        let offsetY           : Double                  = 170.0
                        let fovFill           : GraphicsContext.Shading = GraphicsContext.Shading.color(darkMode ? Constants.FOV_FILL_DARK   : Constants.FOV_FILL)
                        let fovStroke         : GraphicsContext.Shading = GraphicsContext.Shading.color(darkMode ? Constants.FOV_STROKE_DARK : Constants.FOV_STROKE)
                        let cameraOrientation : CameraOrientation       = fovData!.orientation
                        let fovWidth          : Double                  = fovData!.fovWidth
                        let fovHeight         : Double                  = fovData!.fovHeight
                        let distance          : Double                  = fovData!.distance
                        let fov               : CGRect                  = CGRect(x: width - offsetX, y: height - offsetY, width: 72, height: 48)
                        let fovText           : Text                    = Text(verbatim: "\(String(format: fovWidth >= 10 ? "%.0f" : "%.1f", fovWidth))m x \(String(format: fovHeight >= 10 ? "%.0f" : "%.1f", fovHeight))m").foregroundColor(darkMode ? .white : .black).font(Font.system(size: 14))
                        let distanceText      : Text                    = Text(verbatim: "← \(String(format: distance >= 10 ? "%.0f" : "%.1f", distance))m →").foregroundColor(darkMode ? .white : .black).font(Font.system(size: 14))
                        let fovCenterX        : Double                  = width - offsetX + 36
                        let fovCenterY        : Double                  = height - offsetY + 24
                        
                        let bkgRect           : CGRect                  = CGRect(x: 10, y: height - 110, width: width - 20, height: 30)
                        
                        ctx.fill(Rectangle().path(in: bkgRect), with: GraphicsContext.Shading.color(darkMode ? .black.opacity(0.5) : .white.opacity(0.5)))
                        
                        if cameraOrientation == .portrait {
                            ctx.drawLayer { ctx1 in
                                ctx1.translateBy(x: fovCenterX, y: fovCenterY)
                                ctx1.rotate(by: Angle(degrees: -90))
                                ctx1.translateBy(x: -fovCenterX, y: -fovCenterY)
                                ctx1.fill(Rectangle().path(in: fov), with: fovFill)
                                ctx1.stroke(Rectangle().path(in: fov), with: fovStroke)
                            }
                        } else {
                            ctx.fill(Rectangle().path(in: fov), with: fovFill)
                            ctx.stroke(Rectangle().path(in: fov), with: fovStroke)
                        }
                        ctx.draw(fovText, at: CGPoint(x: fovCenterX, y: height - offsetY + 75))
                        
                        if let cameraSymbol = ctx.resolveSymbol(id: 1) {
                            ctx.draw(cameraSymbol, at: CGPoint(x: 50, y: height - offsetY + 75))
                        }
                        ctx.draw(distanceText, at: CGPoint(x: 125, y: height - offsetY + 75))
                        if let photoSymbol = ctx.resolveSymbol(id: 2) {
                            ctx.draw(photoSymbol, at: CGPoint(x: 200, y: height - offsetY + 75))
                        }
                        
                    }
                } symbols: {
                    Image(systemName: "camera")
                        .resizable()
                        .frame(width: 24, height: 19.417)
                        .foregroundColor(self.colorScheme == .dark ? .white : .black)
                        .tag(1)
                    Image(systemName: "photo")
                        .resizable()
                        .frame(width: 24, height: 18.738)
                        .foregroundColor(self.colorScheme == .dark ? .white : .black)
                        .tag(2)
                }
            }
        }
    }
}

#Preview {
    OverlayView()
}
