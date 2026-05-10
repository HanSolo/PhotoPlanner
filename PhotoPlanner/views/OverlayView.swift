//
//  OverlayView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 30.04.26.
//

import SwiftUI
import CoreLocation


struct OverlayView: View {
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(PhotoPlannerModel.self) private var model

    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { ctx, size in
                    let fovData : FoVData? = self.model.fovData
                    if nil != fovData {
                        let darkMode               : Bool                                 = self.colorScheme == .dark
                        let isLandscape            : Bool                                 = UIDevice.current.orientation.isLandscape
                        let width                  : Double                               = size.width
                        let height                 : Double                               = size.height
                        let minSize                : Double                               = isLandscape ? height : width
                        let center                 : CGPoint                              = CGPoint(x: width * 0.5, y: height * 0.5)
                        let offsetX                : Double                               = 50.0
                        let offsetY                : Double                               = 145.0
                        let fovFill                : GraphicsContext.Shading              = GraphicsContext.Shading.color(darkMode ? Constants.FOV_FILL_DARK   : Constants.FOV_FILL)
                        let fovStroke              : GraphicsContext.Shading              = GraphicsContext.Shading.color(darkMode ? Constants.FOV_STROKE_DARK : Constants.FOV_STROKE)
                        let cameraOrientation      : CameraOrientation                    = fovData!.orientation
                        let fovWidth               : Double                               = fovData!.fovWidth
                        let fovHeight              : Double                               = fovData!.fovHeight
                        let distance               : Double                               = fovData!.distance
                        let fov                    : CGRect                               = CGRect(x: width - offsetX, y: height - offsetY, width: 36, height: 24)
                        let fovText                : Text                                 = Text(verbatim: "\(String(format: fovWidth >= 10 ? "%.0f" : "%.1f", fovWidth))m x \(String(format: fovHeight >= 10 ? "%.0f" : "%.1f", fovHeight))m").foregroundColor(darkMode ? .white : .black).font(Font.system(size: 14))
                        let distanceText           : Text                                 = Text(verbatim: "← \(String(format: distance >= 10 ? "%.0f" : "%.1f", distance))m →").foregroundColor(darkMode ? .white : .black).font(Font.system(size: 14))
                        let fovCenterX             : Double                               = width - offsetX + 18
                        let fovCenterY             : Double                               = height - offsetY + 12
                        let hyperFocalDistance     : Double                               = fovData!.hyperFocal
                        let hyperFocalText         : Text                                 = Text(verbatim: "Hyperfocal dist. \(String(format: hyperFocalDistance < 10 ? "%.1f" : "%.0f", hyperFocalDistance))m").foregroundColor(darkMode ? .white : .black).font(Font.system(size: 14))
                        
                        let bkgRect                : CGRect                               = CGRect(x: 10, y: height - 103, width: width - 20, height: 103)
                        //let lineWidth              : CGFloat                              = Constants.IS_IPAD ? 2.0 : 1.0
                        
                        let eventTimes             : Dictionary<String, Date>             = self.model.magicHours.getTimes(date: self.model.currentMapDate, lat: self.model.currentMapLocation?.latitude ?? 0.0, lon: self.model.currentMapLocation?.longitude ?? 0.0)
                        let eventAngles            : Dictionary<String, (Double, Double)> = self.model.magicHours.getEventAngles(date: self.model.currentMapDate, lat: self.model.currentMapLocation?.latitude ?? 0.0, lon: self.model.currentMapLocation?.longitude ?? 0.0)
                        let formatString           : String                               = self.model.metric ? Constants.TWENTY_FOUR_HOUR_FORMAT : Constants.TWELVE_HOUR_FORMAT
                        let sunriseText            : String                               = Helper.dateToString(fromDate: eventTimes[Constants.EPD_SUNRISE]!, formatString: formatString)
                        let sunsetText             : String                               = Helper.dateToString(fromDate: eventTimes[Constants.EPD_SUNSET]!, formatString: formatString)
                        let sunIsUp                : Bool                                 = self.model.currentMapDate >= eventTimes[Constants.EPD_SUNRISE]! && self.model.currentMapDate <= eventTimes[Constants.EPD_SUNSET]!
                        //let moonIsUp               : Bool                                 = now >= eventTimes[Constants.EPD_MOONRISE]! && now <= eventTimes[Constants.EPD_MOONSET]!
                        let sunRiseSetColor        : Color                                = .orange
                        let blueHourColor          : Color                                = .blue
                        let goldenHourColor        : Color                                = Color(red: 1.0, green: 0.54, blue: 0.0)
                        let sunColor               : Color                                = sunIsUp ? .yellow : .yellow.opacity(0.3)
                        let moonColor              : Color                                = Color(red: 0.0, green: 0.44, blue: 1.0, opacity: 1.0)
                        let sunTextAngleOffset     : Double                               = self.model.metric ? 9 : 12
                        //let isDayLightSavingTime   : Bool                                 = TimeZone.current.isDaylightSavingTime()
                        //let timeZoneOffset         : Int                                  = TimeZone.current.secondsFromGMT()
                        var blueHourDawnAngle      : Double                               = 0.0
                        var blueHourDawnEndAngle   : Double                               = 0.0
                        var goldenHourDawnAngle    : Double                               = 0.0
                        var goldenHourDawnEndAngle : Double                               = 0.0
                        var sunriseAngle           : Double                               = 0.0
                        var sunsetAngle            : Double                               = 0.0
                        var goldenHourDuskAngle    : Double                               = 0.0
                        var goldenHourDuskEndAngle : Double                               = 0.0
                        var blueHourDuskAngle      : Double                               = 0.0
                        var blueHourDuskEndAngle   : Double                               = 0.0
                                                
                        let minorDirectionFontSize : Double                               = minSize * 0.03
                        let minorDirectionFont     : Font                                 = Font.system(size: minorDirectionFontSize)
                        let smallDegreeFontSize    : Double                               = minSize * 0.03
                        let smallDegreeFont        : Font                                 = Font.system(size: smallDegreeFontSize)
                        let textColor              : Color                                = darkMode ? Constants.TEXT_DARK : Constants.TEXT_BRIGHT
                                                
                        let innerRingLineWidth     : Double                               = minSize * 0.0666666666
                        let innerRingRadius        : Double                               = minSize * 0.25
                        let outerRingRadius        : Double                               = innerRingRadius + innerRingLineWidth
                        
                        
                        for (event, angles) in eventAngles {
                            let angle   : Double = 180.0 - Helper.toDegrees(angles.0) - (self.model.currentMapHeading ?? 0.0)
                            let endAngle: Double = 180.0 - Helper.toDegrees(angles.1) - (self.model.currentMapHeading ?? 0.0)
                            switch event {
                                case Constants.EPD_BLUE_HOUR_MORNING:
                                    blueHourDuskAngle      = angle
                                    blueHourDuskEndAngle   = endAngle
                                case Constants.EPD_GOLDEN_HOUR_MORNING:
                                    goldenHourDuskAngle    = angle
                                    goldenHourDuskEndAngle = endAngle
                                case Constants.EPD_GOLDEN_HOUR_EVENING:
                                    goldenHourDawnAngle    = angle
                                    goldenHourDawnEndAngle = endAngle
                                case Constants.EPD_BLUE_HOUR_EVENING:
                                    blueHourDawnAngle      = angle
                                    blueHourDawnEndAngle   = endAngle
                                case Constants.EPD_SUNRISE:
                                    sunriseAngle           = angle
                                case Constants.EPD_SUNSET:
                                    sunsetAngle            = angle
                                default:
                                    break
                            }
                        }
                                                                        
                        ctx.fill(Rectangle().path(in: bkgRect), with: GraphicsContext.Shading.color(darkMode ? .black.opacity(0.5) : .white.opacity(0.5)))
                        
                        ctx.draw(hyperFocalText, at: CGPoint(x: 20, y: height - offsetY + 12), anchor: .leading)
                        
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
                        ctx.draw(fovText, at: CGPoint(x: width - 20, y: height - offsetY + 60), anchor: .trailing)
                        
                        if let cameraSymbol = ctx.resolveSymbol(id: 1) {
                            ctx.draw(cameraSymbol, at: CGPoint(x: 20, y: height - offsetY + 60), anchor: .leading)
                        }
                        ctx.draw(distanceText, at: CGPoint(x: 102, y: height - offsetY + 60), anchor: .center)
                        if let photoSymbol = ctx.resolveSymbol(id: 2) {
                            ctx.draw(photoSymbol, at: CGPoint(x: 160, y: height - offsetY + 60), anchor: .leading)
                        }
                        
                        
                        // Magic Hours
                        if self.model.epdVisible {
                            ctx.drawLayer { ctx1 in
                                
                                let eventLineWidth : CGFloat = Constants.IS_IPAD ? 2 : 1
                                
                                for(event, angles) in eventAngles {
                                    let angle : Double = 180.0 - Helper.toDegrees(angles.0) + (self.model.currentMapHeading ?? 0.0)
                                    
                                    ctx1.translateBy(x: center.x, y: center.y)
                                    ctx1.rotate(by: Angle(degrees: -angle))
                                    ctx1.translateBy(x: -center.x, y: -center.y)
                                                                                                            
                                    var path: Path = Path()
                                    path.move(to: CGPoint(x: center.x, y: center.y - innerRingRadius))
                                    path.addLine(to: CGPoint(x: center.x, y: center.y - outerRingRadius))
                                    path.closeSubpath()
                                    switch event {
                                        case Constants.EPD_SUNRISE :
                                            let text : Text = Text(verbatim: "\(sunriseText)").foregroundColor(textColor).font(minorDirectionFont)
                                            ctx1.stroke(path, with: GraphicsContext.Shading.color(sunRiseSetColor), lineWidth: eventLineWidth)
                                            ctx1.drawLayer { ctx2 in
                                                ctx2.translateBy(x: center.x, y: center.y)
                                                ctx2.rotate(by: Angle(degrees: -sunTextAngleOffset))
                                                ctx2.translateBy(x: -center.x, y: -center.y)
                                                ctx2.draw(text, at: CGPoint(x: center.x, y: center.y - outerRingRadius - minorDirectionFontSize), anchor: .center)
                                            }
                                        case Constants.EPD_SUNSET  :
                                            let text : Text = Text(verbatim: "\(sunsetText)").foregroundColor(textColor).font(minorDirectionFont)
                                            ctx1.stroke(path, with: GraphicsContext.Shading.color(sunRiseSetColor), lineWidth: eventLineWidth)
                                            ctx1.drawLayer { ctx2 in
                                                ctx2.translateBy(x: center.x, y: center.y)
                                                ctx2.rotate(by: Angle(degrees: +sunTextAngleOffset))
                                                ctx2.translateBy(x: -center.x, y: -center.y)
                                                ctx2.draw(text, at: CGPoint(x: center.x, y: center.y - outerRingRadius - minorDirectionFontSize), anchor: .center)
                                            }
                                        case Constants.EPD_SUN     :
                                            ctx1.stroke(path, with: GraphicsContext.Shading.color(sunColor), lineWidth: eventLineWidth)
                                        case Constants.EPD_MOON    :
                                            ctx1.stroke(path, with: GraphicsContext.Shading.color(moonColor), lineWidth: eventLineWidth)
                                        default                    : break
                                    }
                                    
                                    ctx1.translateBy(x: center.x, y: center.y)
                                    ctx1.rotate(by: Angle(degrees: angle))
                                    ctx1.translateBy(x: -center.x, y: -center.y)
                                }

                                // Draw daylight arc
                                var sunPath: Path = Path()
                                sunPath.addArc(center: CGPoint(x: center.x, y: center.y), radius: innerRingRadius, startAngle: .degrees(sunriseAngle - 90.0), endAngle: .degrees(sunsetAngle - 90.0), clockwise: true)
                                ctx1.stroke(sunPath, with: GraphicsContext.Shading.color(sunRiseSetColor), lineWidth: 1)
                                if sunIsUp {
                                    var sunIsUpPath: Path = Path()
                                    sunIsUpPath.addArc(center: CGPoint(x: center.x, y: center.y), radius: innerRingRadius + innerRingLineWidth * 0.5, startAngle: .degrees(sunriseAngle - 90.0), endAngle: .degrees(sunsetAngle - 90.0), clockwise: true)
                                    ctx1.stroke(sunIsUpPath, with: GraphicsContext.Shading.color(sunColor.opacity(0.15)), lineWidth: innerRingLineWidth)
                                }
                                
                                // Draw blue hour dawn
                                var blueHourDawnPath: Path = Path()
                                blueHourDawnPath.addArc(center: CGPoint(x: center.x, y: center.y), radius: innerRingRadius + innerRingLineWidth * 0.5, startAngle: .degrees(blueHourDawnAngle - 90.0), endAngle: .degrees(blueHourDawnEndAngle - 90.0), clockwise: true)
                                ctx1.stroke(blueHourDawnPath, with: GraphicsContext.Shading.color(blueHourColor.opacity(0.4)), lineWidth: innerRingLineWidth)
                                
                                // Draw golden hour dawn
                                var goldenHourDawnPath: Path = Path()
                                goldenHourDawnPath.addArc(center: CGPoint(x: center.x, y: center.y), radius: innerRingRadius + innerRingLineWidth * 0.5, startAngle: .degrees(goldenHourDawnAngle - 90.0), endAngle: .degrees(goldenHourDawnEndAngle - 90.0), clockwise: true)
                                ctx1.stroke(goldenHourDawnPath, with: GraphicsContext.Shading.color(goldenHourColor.opacity(0.4)), lineWidth: innerRingLineWidth)
                                
                                
                                // Draw blue hour dusk
                                var blueHourDuskPath: Path = Path()
                                blueHourDuskPath.addArc(center: CGPoint(x: center.x, y: center.y), radius: innerRingRadius + innerRingLineWidth * 0.5, startAngle: .degrees(blueHourDuskAngle - 90.0), endAngle: .degrees(blueHourDuskEndAngle - 90.0), clockwise: true)
                                ctx1.stroke(blueHourDuskPath, with: GraphicsContext.Shading.color(blueHourColor.opacity(0.4)), lineWidth: innerRingLineWidth)
                                
                                // Draw golden hour dusk
                                var goldenHourDuskPath: Path = Path()
                                goldenHourDuskPath.addArc(center: CGPoint(x: center.x, y: center.y), radius: innerRingRadius + innerRingLineWidth * 0.5, startAngle: .degrees(goldenHourDuskAngle - 90.0), endAngle: .degrees(goldenHourDuskEndAngle - 90.0), clockwise: true)
                                ctx1.stroke(goldenHourDuskPath, with: GraphicsContext.Shading.color(goldenHourColor.opacity(0.4)), lineWidth: innerRingLineWidth)
                            }
                            
                            // Draw text and tickmarks
                            ctx.drawLayer { ctx1 in
                                ctx1.translateBy(x: center.x, y: center.y)
                                ctx1.rotate(by: Angle(degrees: -(self.model.currentMapHeading ?? 0.0)))
                                ctx1.translateBy(x: -center.x, y: -center.y)
                                                                                                
                                // Draw hours of day 15°
                                let calendar    : Calendar                             = Calendar.current
                                for hour in stride(from: 0, to: 24, by: 1) {
                                    let tmpDate : Date                                 = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: self.model.currentMapDate)!
                                    let angles  : Dictionary<String, (Double, Double)> = self.model.magicHours.getEventAngles(date: tmpDate, lat: self.model.currentMapLocation?.latitude ?? 0.0, lon: self.model.currentMapLocation?.longitude ?? 0.0)
                                    let text    : Text                                 = Text(verbatim: "\(hour)").font(smallDegreeFont).foregroundColor(textColor)
                                    let angle   : Double                               = Helper.toDegrees(angles[Constants.EPD_SUN]!.0) - (self.model.currentMapHeading ?? 0.0)
                                    let xy      : (Double, Double)                     = Helper.rotatePointAroundRotationCenter(x: center.x, y: center.y + innerRingRadius - smallDegreeFontSize, rotationCenterX: center.x, rotationCenterY: center.y, angleDeg: angle + (self.model.currentMapHeading ?? 0.0))
                                    ctx1.drawLayer { ctx2 in
                                        ctx2.translateBy(x: xy.0, y: xy.1)
                                        ctx2.rotate(by: Angle(degrees: angle + (self.model.currentMapHeading ?? 0.0)))
                                        ctx2.draw(text, at: CGPoint(x: 0, y: 0), anchor: .center)
                                    }
                                }
                            }
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
