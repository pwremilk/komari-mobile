//
//  Utilities.swift
//  Komari Mobile
//
//  Created by Junhui Lou on 2/15/26.
//

import Foundation
import SwiftUI
import UIKit

// Copy text
func copy(_ text: String) {
    UIPasteboard.general.string = text
}

// Handle empty name
func nameCanBeUntitled(_ name: String?) -> String {
    guard let name = name else { return String(localized: "Untitled") }
    return name != "" ? name : String(localized: "Untitled")
}

// Bytes To Data Amount String
func formatBytes(_ bytes: Int64, decimals: Int = 2) -> String {
    let units = ["B", "KB", "MB", "GB", "TB", "PB"]
    var value = Double(bytes)
    var unitIndex = 0

    while value >= 1024 && unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = decimals
    formatter.roundingMode = .ceiling

    guard let formattedValue = formatter.string(from: NSNumber(value: value)) else {
        return ""
    }

    return "\(formattedValue) \(units[unitIndex])"
}

// Seconds To Interval String
func formatTimeInterval(seconds: Int64, compact: Bool = false, shortened: Bool = false) -> String {
    let minutes = seconds / 60
    let hours = minutes / 60
    let days = hours / 24

    if days >= 10 {
        return compact ? "\(days) d" : String(localized: "\(days) Day(s)")
    } else if days > 0 {
        return compact ? (shortened ? "\(days) d" : "\(days) d \(hours % 24) h") : String(localized: "\(days) Day(s) and \(hours % 24) Hour(s)")
    } else if hours > 0 {
        return compact ? (shortened ? "\(hours) h" : "\(hours) h \(minutes % 60) m") : String(localized: "\(days) Hour(s) and \(hours % 24) Minute(s)")
    } else if minutes > 0 {
        return compact ? (shortened ? "\(minutes) m" : "\(minutes) m \(seconds % 60) s") : String(localized: "\(days) Minute(s) and \(hours % 24) Second(s)")
    } else {
        return compact ? "\(seconds) s" : String(localized: "\(seconds) Second(s)")
    }
}

// Capitalizer
extension String {
    func capitalizeFirstLetter() -> String {
        guard !self.isEmpty else { return self }
        return self.prefix(1).uppercased() + self.dropFirst()
    }
}

// "if" Modifier
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
