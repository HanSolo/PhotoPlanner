//
//  Calendar+withTimezone.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 21.05.26.
//

import Foundation


extension Calendar {
    func with(timeZone: TimeZone) -> Calendar {
        var calendar      : Calendar = self
        calendar.timeZone = timeZone
        return calendar
    }
}
