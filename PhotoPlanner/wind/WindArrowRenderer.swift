//
//  WindArrowRenderer.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 20.08.26.
//

import Foundation
import SwiftUI


struct WindArrowRenderer {
 
    // Speed based color: green (calm), yellow,        orange,         red (strong)
    // Thresholds       : <3 m/s green, <8 m/s yellow, <14 m/s orange, 14+ m/s red
    private static func arrowColor(for speedMs: Double) -> UIColor {
        switch speedMs {
            case ..<3   : return UIColor(red: 0.2, green: 0.85, blue: 0.2,  alpha: 1) // green
            case 3..<8  : return UIColor(red: 0.95, green: 0.85, blue: 0.1, alpha: 1) // yellow
            case 8..<14 : return UIColor(red: 1.0,  green: 0.5,  blue: 0.0, alpha: 1) // orange
            default     : return UIColor(red: 1.0,  green: 0.15, blue: 0.1, alpha: 1) // red
        }
    }
 
    // Draws wind arrows onto a UIImage using speed-based color coding.
    static func draw(onto image: UIImage, samples: [WindSample], at date: Date, regionLat: Double, regionLon: Double, centerLat: Double, centerLon: Double) -> UIImage {
        let size     : CGSize                  = image.size
        let renderer : UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: size)
 
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
 
            for sample in samples {
                guard let wind : WindHour = sample.wind(at: date) else { continue }
                guard wind.speedMs > 0.5 else { continue }
 
                let minLat : CGFloat = centerLat - regionLat / 2
                let minLon : CGFloat = centerLon - regionLon / 2
                let xFrac  : CGFloat = (sample.longitude - minLon) / regionLon
                let yFrac  : CGFloat = 1.0 - (sample.latitude - minLat) / regionLat
                let point  : CGPoint = CGPoint(x: xFrac * size.width, y: yFrac * size.height)
 
                // Opacity scales with speed — always at least 0.5 so arrows are visible
                let opacity : CGFloat = min(1.0, max(0.5, wind.speedMs / 15.0))
 
                let toDeg : CGFloat = (wind.directionDeg + 180).truncatingRemainder(dividingBy: 360)
                let angle : CGFloat = CGFloat((90 - toDeg) * .pi / 180)
 
                drawArrow(at: point, angle: angle, opacity: CGFloat(opacity), color: arrowColor(for: wind.speedMs))
            }
        }
    }
 
    private static func drawArrow(at point: CGPoint, angle: CGFloat, opacity: CGFloat, color: UIColor) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
 
        let arrowLength : CGFloat = 28
        let headLength  : CGFloat = 9
        let headWidth   : CGFloat = 7
        let lineWidth   : CGFloat = 2.5
 
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)
        ctx.rotate(by: -angle)   // negative because UIKit y-axis is flipped
        ctx.setAlpha(opacity)
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
 
        // Shaft — from tail to just before arrowhead
        ctx.move(to:    CGPoint(x: -arrowLength / 2, y: 0))
        ctx.addLine(to: CGPoint(x:  arrowLength / 2 - headLength, y: 0))
        ctx.strokePath()
 
        // Arrowhead triangle
        ctx.move(to:    CGPoint(x:  arrowLength / 2, y: 0))
        ctx.addLine(to: CGPoint(x:  arrowLength / 2 - headLength, y: -headWidth / 2))
        ctx.addLine(to: CGPoint(x:  arrowLength / 2 - headLength, y:  headWidth / 2))
        ctx.closePath()
        ctx.fillPath()
 
        ctx.restoreGState()
    }
}
