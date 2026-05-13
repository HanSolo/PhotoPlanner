//
//  ElevationProfileView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 08.05.26.
//

import SwiftUI


struct ElevationProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    let profile: ElevationProfile?

    var body: some View {        
        GeometryReader { geometry in
            Canvas { ctx, size in
                let darkMode : Bool = self.colorScheme == .dark
                
                if self.profile == nil { return }
                
                guard profile!.points.count >= 2 else { return }

                let elevations   : [Double] = profile!.points.map(\.elevation)
                let minElevation : Double   = elevations.min()!
                let maxElevation : Double   = max(elevations.max()!, profile!.cameraEyeAltitude, profile!.subjectAltitude)
                let range        : Double   = max(maxElevation - minElevation, 1)

                func x(for index: Int) -> CGFloat {
                    CGFloat(index) / CGFloat(profile!.points.count - 1) * size.width
                }

                func y(for elevation: Double) -> CGFloat {
                    let normalized = (elevation - minElevation) / range
                    return size.height - 2 - normalized * (size.height - 4)
                }
            
                var fillPath = Path()
                fillPath.move(to: CGPoint(x: x(for: 0), y: size.height))
                for (index, point) in profile!.points.enumerated() {
                    fillPath.addLine(to: CGPoint(x: x(for: index), y: y(for: point.elevation)))
                }
                fillPath.addLine(to: CGPoint(x: x(for: profile!.points.count - 1), y: size.height))
                fillPath.closeSubpath()

                ctx.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [.blue.opacity(0.6), .blue.opacity(0.15)]),
                        startPoint: CGPoint(x: size.width / 2, y: 0),
                        endPoint:   CGPoint(x: size.width / 2, y: size.height)
                    )
                )

                var strokePath = Path()
                strokePath.move(to: CGPoint(x: x(for: 0), y: y(for: profile!.points[0].elevation)))
                for (index, point) in profile!.points.dropFirst().enumerated() {
                    strokePath.addLine(to: CGPoint(x: x(for: index + 1), y: y(for: point.elevation)))
                }

                ctx.stroke(strokePath, with: .color(.blue), lineWidth: 1.5)

                let cameraPoint : CGPoint = CGPoint(x: x(for: 0), y: y(for: profile!.cameraEyeAltitude))
                let motifPoint  : CGPoint = CGPoint(x: x(for: profile!.points.count - 1), y: y(for: profile!.subjectAltitude))

                var losPath = Path()
                losPath.move(to: cameraPoint)
                losPath.addLine(to: motifPoint)

                // Red if blocked, orange if clear
                let losColor: Color = profile!.hasLineOfSight ? .white : .red
                ctx.stroke(
                    losPath,
                    with: .color(losColor.opacity(0.8)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )

                // Camera pin at eye height
                ctx.fill(Path(ellipseIn: CGRect(x: cameraPoint.x - 3, y: cameraPoint.y - 3, width: 6, height: 6)),with: .color(.white))
                ctx.stroke(Path(ellipseIn: CGRect(x: cameraPoint.x - 3, y: cameraPoint.y - 3, width: 6, height: 6)),with: .color(.blue), lineWidth: 1.5)

                // Motif pin at motif height
                ctx.fill(Path(ellipseIn: CGRect(x: motifPoint.x - 3, y: motifPoint.y - 3, width: 6, height: 6)),with: .color(.white))
                ctx.stroke(Path(ellipseIn: CGRect(x: motifPoint.x - 3, y: motifPoint.y - 3, width: 6, height: 6)),with: .color(.blue), lineWidth: 1.5)
                
                let fontSize       : Double = 10
                let font           : Font   = Font.system(size: fontSize)
                let textColor      : Color  = darkMode ? Constants.TEXT_DARK : Constants.TEXT_BRIGHT
                let cameraAltitude : Text   = Text(verbatim: "\(String(format: profile!.cameraEyeAltitude >= 10 ? "%.0f" : "%.1f", profile!.cameraEyeAltitude))m").font(font).foregroundColor(textColor)
                let motifAltitude  : Text   = Text(verbatim: "\(String(format: profile!.subjectAltitude >= 10 ? "%.0f" : "%.1f", profile!.subjectAltitude))m").font(font).foregroundColor(textColor)
                ctx.draw(cameraAltitude, at: CGPoint(x: cameraPoint.x + 5, y: size.height - fontSize * 1.5), anchor: .leading)
                ctx.draw(motifAltitude, at: CGPoint(x: motifPoint.x - 5, y: size.height - fontSize * 1.5), anchor: .trailing)
                
                // Draw line for surface
                var surface : Path = Path()
                surface.move(to: CGPoint(x: 0, y: size.height))
                surface.addLine(to: CGPoint(x: size.width, y: size.height))
                ctx.stroke(surface, with: .color(.white), lineWidth: 1.0)
            }
            .frame(maxWidth: geometry.size.width, maxHeight: 50)
            .background(.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .offset(y: geometry.size.height - 153)
            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
        }
    }
}
