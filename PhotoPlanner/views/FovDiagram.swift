//
//  FovDiagram.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.08.26.
//

import Foundation
import SwiftUI


struct FovDiagram: View {
    @Environment(\.colorScheme) private var colorScheme
    let vm : FovViewModel

    var body: some View {
        Canvas { ctx, size in
            let dof      = vm.dof
            let maxDist  = vm.maxDisplayDistance
            let w        = size.width
            let h        = size.height

            // Layout constants
            let leftMargin  : CGFloat = 52   // Y axis labels
            let rightMargin : CGFloat = 70   // right side labels
            let topMargin   : CGFloat = 16
            let bottomMargin: CGFloat = 32   // camera label

            let drawW = w - leftMargin - rightMargin
            let drawH = h - topMargin - bottomMargin

            // Convert distance (metres) to Y pixel, camera at the bottom
            func yPos(_ dist: Double) -> CGFloat {
                let fraction = CGFloat(min(dist, maxDist) / maxDist)
                return topMargin + drawH * (1.0 - fraction)
            }

            // FOV half-angle for horizontal axis
            let sensorW   : CGFloat = vm.isLandscape ? vm.sensorFormat.width : vm.sensorFormat.height
            let hFovRad   : CGFloat = 2.0 * atan((sensorW / 2.0) / vm.focalLength)
            let halfAngle : CGFloat = hFovRad / 2.0

            // Camera apex at bottom centre
            let apexX : CGFloat = leftMargin + drawW / 2
            let apexY : CGFloat = topMargin + drawH + bottomMargin / 2

            // FOV triangle edges at maxDist
            let pixelsPerMetre : CGFloat = drawW / 2 / CGFloat(tan(halfAngle) * maxDist)

            func xLeft(_ dist: Double) -> CGFloat  { apexX - CGFloat(tan(halfAngle) * dist) * pixelsPerMetre }
            func xRight(_ dist: Double) -> CGFloat { apexX + CGFloat(tan(halfAngle) * dist) * pixelsPerMetre }

            // Grid lines            
            let gridColor : Color  = Color(colorScheme == .dark ? UIColor.systemGray2 : UIColor.systemGray)
            let gridStep  : Double = niceStep(max: maxDist)

            var d : Double = gridStep
            while d <= maxDist {
                let y : CGFloat = yPos(d)
                var path = Path()
                path.move(to: CGPoint(x: leftMargin, y: y))
                path.addLine(to: CGPoint(x: leftMargin + drawW, y: y))
                ctx.stroke(path, with: .color(gridColor.opacity(0.4)), lineWidth: 0.5)

                // Y axis label
                let label : String = formatDistance(d)
                ctx.draw(
                    Text(label).font(.system(size: 9).monospacedDigit()).foregroundStyle(gridColor),
                    at: CGPoint(x: leftMargin - 4, y: y),
                    anchor: .trailing
                )
                d += gridStep
            }

            // Legend, drawn in bottom left of diagram area
            let legendX : CGFloat = leftMargin + 6
            let legendY : CGFloat = topMargin + drawH - 60   // 60pt from bottom
            let lineLen : CGFloat = 14

            // FOV triangle line
            var fovLegend = Path()
            fovLegend.move(to:    CGPoint(x: legendX,           y: legendY))
            fovLegend.addLine(to: CGPoint(x: legendX + lineLen, y: legendY))
            ctx.stroke(fovLegend, with: .color(Color.accentColor.opacity(0.7)), lineWidth: 1.5)
            ctx.draw(
                Text("Field of View").font(.system(size: 8)).foregroundStyle(Color.accentColor.opacity(0.9)),
                at: CGPoint(x: legendX + lineLen + 4, y: legendY),
                anchor: .leading
            )

            // DOF band
            var dofLegend = Path()
            dofLegend.move(to:    CGPoint(x: legendX,           y: legendY + 14))
            dofLegend.addLine(to: CGPoint(x: legendX + lineLen, y: legendY + 14))
            ctx.stroke(dofLegend, with: .color(Color.blue.opacity(0.7)), lineWidth: 1.5)
            ctx.draw(
                Text("Depth of Field").font(.system(size: 8)).foregroundStyle(Color.blue.opacity(0.9)),
                at: CGPoint(x: legendX + lineLen + 4, y: legendY + 14),
                anchor: .leading
            )

            // Focus line
            var focusLegend = Path()
            focusLegend.move(to:    CGPoint(x: legendX,           y: legendY + 28))
            focusLegend.addLine(to: CGPoint(x: legendX + lineLen, y: legendY + 28))
            ctx.stroke(focusLegend, with: .color(Color.orange), lineWidth: 2)
            ctx.draw(
                Text("Focus Distance").font(.system(size: 8)).foregroundStyle(Color.orange),
                at: CGPoint(x: legendX + lineLen + 4, y: legendY + 28),
                anchor: .leading
            )
            
            // FOV triangle
            var fovPath = Path()
            fovPath.move(to: CGPoint(x: apexX, y: apexY))
            fovPath.addLine(to: CGPoint(x: xLeft(maxDist), y: topMargin))
            fovPath.addLine(to: CGPoint(x: xRight(maxDist), y: topMargin))
            fovPath.closeSubpath()

            ctx.fill(fovPath, with: .color(Color.accentColor.opacity(0.08)))
            ctx.stroke(fovPath, with: .color(Color.accentColor.opacity(0.35)), lineWidth: 1.5)

            // DOF area
            let nearY = yPos(dof.nearLimit)
            let farDist  = dof.farLimit.isInfinite ? maxDist : min(dof.farLimit, maxDist)
            let farY  = yPos(farDist)

            let nearLeft  = xLeft(dof.nearLimit)
            let nearRight = xRight(dof.nearLimit)
            let farLeft   = xLeft(farDist)
            let farRight  = xRight(farDist)

            // DOF area trapezoid, clipped to FOV triangle
            var dofPath = Path()
            dofPath.move(to:    CGPoint(x: nearLeft,  y: nearY))
            dofPath.addLine(to: CGPoint(x: nearRight, y: nearY))
            dofPath.addLine(to: CGPoint(x: farRight,  y: farY))
            dofPath.addLine(to: CGPoint(x: farLeft,   y: farY))
            dofPath.closeSubpath()

            // Clip dofPath to fovPath to prevent overflow
            ctx.drawLayer { layerCtx in
                layerCtx.clip(to: fovPath)   // clip to FOV triangle first
                layerCtx.fill(dofPath, with: .color(Color.blue.opacity(0.15)))

                // Hatch lines
                layerCtx.drawLayer { hatchCtx in
                    hatchCtx.clip(to: dofPath)
                    let hatchSpacing : CGFloat = 8
                    let hatchCount   : Int     = Int((drawH + drawW) / hatchSpacing) + 2
                    for i in 0..<hatchCount {
                        let offset : CGFloat = CGFloat(i) * hatchSpacing
                        var hatch  : Path    = Path()
                        hatch.move(to: CGPoint(x: leftMargin, y: topMargin + offset))
                        hatch.addLine(to: CGPoint(x: leftMargin + offset, y: topMargin))
                        hatchCtx.stroke(hatch, with: .color(Color.blue.opacity(0.25)), lineWidth: 0.8)
                    }
                }

                // DOF area borders
                var nearLine : Path = Path()
                nearLine.move(to: CGPoint(x: nearLeft,  y: nearY))
                nearLine.addLine(to: CGPoint(x: nearRight, y: nearY))
                layerCtx.stroke(nearLine, with: .color(.blue.opacity(0.7)), lineWidth: 1.5)

                var farLine : Path = Path()
                farLine.move(to: CGPoint(x: farLeft,  y: farY))
                farLine.addLine(to: CGPoint(x: farRight, y: farY))
                layerCtx.stroke(farLine, with: .color(.blue.opacity(0.7)), lineWidth: 1.5)
            }

            var farLine : Path = Path()
            farLine.move(to:    CGPoint(x: farLeft,  y: farY))
            farLine.addLine(to: CGPoint(x: farRight, y: farY))
            ctx.stroke(farLine, with: .color(.blue.opacity(0.7)), lineWidth: 1.5)

            // Focus distance line
            let focusY     = yPos(vm.focusDistance)
            let focusLeft  = xLeft(vm.focusDistance)
            let focusRight = xRight(vm.focusDistance)

            var focusLine : Path = Path()
            focusLine.move(to: CGPoint(x: focusLeft, y: focusY))
            focusLine.addLine(to: CGPoint(x: focusRight, y: focusY))
            ctx.stroke(focusLine, with: .color(.orange), lineWidth: 2)

            // Focus diamond marker
            let diamondSize : CGFloat = 8
            var diamond     : Path    = Path()
            diamond.move(to: CGPoint(x: focusRight + diamondSize, y: focusY))
            diamond.addLine(to: CGPoint(x: focusRight, y: focusY - diamondSize))
            diamond.addLine(to: CGPoint(x: focusRight + diamondSize * 2, y: focusY - diamondSize))
            diamond.addLine(to: CGPoint(x: focusRight + diamondSize * 2, y: focusY + diamondSize))
            diamond.addLine(to: CGPoint(x: focusRight, y: focusY + diamondSize))
            diamond.closeSubpath()            

            // Simple diamond
            var diam : Path    = Path()
            let dc   : CGPoint = CGPoint(x: focusRight + 16, y: focusY)
            diam.move(to: CGPoint(x: dc.x, y: dc.y - 7))
            diam.addLine(to: CGPoint(x: dc.x + 7, y: dc.y))
            diam.addLine(to: CGPoint(x: dc.x, y: dc.y + 7))
            diam.addLine(to: CGPoint(x: dc.x - 7, y: dc.y))
            diam.closeSubpath()
            ctx.fill(diam, with: .color(.orange))

            // Labels on right side
            let labelX : CGFloat = leftMargin + drawW + 6

            // Far DOF
            let farLabel : String = dof.farLimit.isInfinite ? "∞" : formatDistance(dof.farLimit)
            ctx.draw(
                Text(farLabel)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.blue),
                at: CGPoint(x: labelX, y: farY),
                anchor: .leading
            )

            // Focus distance
            ctx.draw(
                Text(formatDistance(vm.focusDistance))
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.orange),
                at: CGPoint(x: labelX, y: focusY + 10),
                anchor: .leading
            )

            // Near DOF
            ctx.draw(
                Text(formatDistance(dof.nearLimit))
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.blue),
                at: CGPoint(x: labelX, y: nearY),
                anchor: .leading
            )

            // DOF spread labels on left of area
            let dofFront : CGFloat = vm.focusDistance - dof.nearLimit
            let dofRear  : CGFloat = dof.farLimit.isInfinite ? Double.infinity : (dof.farLimit - vm.focusDistance)

            let midFrontY : CGFloat = (nearY + focusY) / 2
            let midRearY  : CGFloat = (focusY + farY)  / 2

            ctx.draw(
                Text(formatDistance(dofFront))
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(Color.blue.opacity(0.8)),
                at: CGPoint(x: labelX, y: midFrontY),
                anchor: .leading
            )

            if !dof.farLimit.isInfinite {
                ctx.draw(
                    Text(formatDistance(dofRear))
                        .font(.system(size: 8).monospacedDigit())
                        .foregroundStyle(Color.blue.opacity(0.8)),
                    at: CGPoint(x: labelX, y: midRearY),
                    anchor: .leading
                )
            }

            // Camera icon at bottom
            let cameraImage = ctx.resolve(Image(systemName: "camera"))
            ctx.draw(cameraImage, at: CGPoint(x: apexX, y: apexY), anchor: .top)
        }
    }

    // Helpers

    private func formatDistance(_ d: Double) -> String {
        if d >= 100  { return String(format: "%.0fm", d) }
        if d >= 10   { return String(format: "%.1fm", d) }
        return String(format: "%.2fm", d)
    }

    private func niceStep(max: Double) -> Double {
        let candidates  = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0]
        let targetLines = 8.0
        let ideal       = max / targetLines
        return candidates.min(by: { abs($0 - ideal) < abs($1 - ideal) }) ?? 1.0
    }
}
