//
//  DateTimeView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 04.05.26.
//

import SwiftUI
import CoreLocation


struct DateTimeView: View {
    @Environment(\.colorScheme)          var colorScheme
    @Environment(\.dismiss)              private var dismiss
    @Environment(PhotoPlannerModel.self) private var model
    
    private let headerFont      : Font       = Font.system(size: 14)
    private let textFont        : Font       = Font.system(size: 14)
    private let goldenHourColor : Color      = Color(red: 1.00, green: 0.58, blue: 0.00)
        
    var body: some View {
        let darkMode          : Bool                     = self.colorScheme == .dark
        let blueHourColor     : Color                    = darkMode ? Color(red: 0.0, green: 0.41, blue: 1.0) : Color(red: 0.02, green: 0.23, blue: 0.615)
        let textColor         : Color                    = darkMode ? .white : .black
        let formatString      : String                   = self.model.metric ? Constants.TWENTY_FOUR_HOUR_FORMAT : Constants.TWELVE_HOUR_FORMAT
        let bhMorningText     : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_BLUE_HOUR_DAWN]!, formatString: formatString)
        let bhMorningEndText  : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_BLUE_HOUR_DAWN_END]!, formatString: formatString)
        let ghMorningText     : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_BLUE_HOUR_DAWN_END]!, formatString: formatString)
        let ghMorningEndText  : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_GOLDEN_HOUR_END]!, formatString: formatString)
        let sunriseText       : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_SUNRISE]!, formatString: formatString)
        let sunsetText        : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_SUNSET]!, formatString: formatString)
        let ghEveningText     : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_GOLDEN_HOUR]!, formatString: formatString)
        let ghEveningEndText  : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_BLUE_HOUR_DUSK]!, formatString: formatString)
        let bhEveningText     : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_BLUE_HOUR_DUSK]!, formatString: formatString)
        let bhEveningEndText  : String                   = Helper.dateToString(fromDate: self.model.sunTimes[Constants.EPD_BLUE_HOUR_DUSK_END]!, formatString: formatString)
        let moonriseText      : String                   = self.model.moonTimes.contains{ $0.key == Constants.EPD_RISE } ? Helper.dateToString(fromDate: self.model.moonTimes[Constants.EPD_RISE]!, formatString: formatString) : ""
        let moonsetText       : String                   = self.model.moonTimes.contains{ $0.key == Constants.EPD_SET } ? Helper.dateToString(fromDate: self.model.moonTimes[Constants.EPD_SET]!, formatString: formatString) : ""
        let daylightHoursText : String                   = Helper.secondsToHHMMString(seconds: (self.model.sunTimes[Constants.EPD_SUNSET]!.timeIntervalSince1970 - self.model.sunTimes[Constants.EPD_SUNRISE]!.timeIntervalSince1970))
        

        NavigationStack {
            VStack {
                HStack(spacing: 10) {
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                }
                .buttonStyle(.glass)
                .padding()
            }
            
            Spacer()
            
            Text("Select Date and Time for calculation")
            
            DatePicker("Select Date and Time", selection: self.model.currentMapDateBinding)
                .labelsHidden()
                .onChange(of: self.model.currentMapDate) {
                    self.model.sunTimes  = self.model.magicHours.getTimes(date: self.model.currentMapDate, lat: self.model.currentMapLocation?.latitude ?? 0.0, lon: self.model.currentMapLocation?.longitude ?? 0.0)
                    self.model.moonTimes = self.model.magicHours.getMoonTimes(date: self.model.currentMapDate, lat: self.model.currentMapLocation?.latitude ?? 0.0, lon: self.model.currentMapLocation?.longitude ?? 0.0)
                }
            
            Form {
                List {
                    Section(header: Text("Blue Hour").foregroundStyle(blueHourColor).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text("\(bhMorningText) - \(bhMorningEndText)")
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                    
                    Section(header: Text("Golden Hour").foregroundStyle(goldenHourColor).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text("\(ghMorningText) - \(ghMorningEndText)")
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                    
                    Section(header: Text("Sunrise").foregroundStyle(.yellow).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text("\(sunriseText)")
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                    
                    Section(header: Text("Daylight").foregroundStyle(.yellow).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text(daylightHoursText)
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                    
                    Section(header: Text("Sunset").foregroundStyle(.yellow).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text("\(sunsetText)")
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                    
                    Section(header: Text("Golden Hour").foregroundStyle(goldenHourColor).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text("\(ghEveningText) - \(ghEveningEndText)")
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                    
                    Section(header: Text("Blue Hour").foregroundStyle(blueHourColor).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text("\(bhEveningText) - \(bhEveningEndText)")
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                    
                    Section(header: Text("Moonrise").foregroundStyle(.gray).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text("\(moonriseText)")
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                    
                    Section(header: Text("Moonset").foregroundStyle(.gray).font(headerFont).listRowInsets(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 0))) {
                        Text("\(moonsetText)")
                            .foregroundStyle(textColor)
                            .font(textFont)
                    }
                }
                .listSectionSpacing(0)
                .task {
                    self.model.sunTimes  = self.model.magicHours.getTimes(date: self.model.currentMapDate, lat: self.model.currentMapLocation?.latitude ?? 0.0, lon: self.model.currentMapLocation?.longitude ?? 0.0)
                    self.model.moonTimes = self.model.magicHours.getMoonTimes(date: self.model.currentMapDate, lat: self.model.currentMapLocation?.latitude ?? 0.0, lon: self.model.currentMapLocation?.longitude ?? 0.0)
                }
            }
            
            Spacer()
        }
    }
}
