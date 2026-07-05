//
//  MortColors.swift
//  MORT
//
//  Central color palette. Dark-first, premium, rose-gold accented.
//

import SwiftUI

extension Color {
    /// Create a Color from a hex string like "#050505" or "050505".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value & 0xFF00_0000) >> 24) / 255
            g = Double((value & 0x00FF_0000) >> 16) / 255
            b = Double((value & 0x0000_FF00) >> 8) / 255
            a = Double(value & 0x0000_00FF) / 255
        default:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// MORT brand colors.
enum MortColor {
    static let productionBlack = Color(hex: "#050505")
    static let softBlack = Color(hex: "#111113")
    static let white = Color(hex: "#FFFFFF")
    static let offWhite = Color(hex: "#F7F7F5")
    static let lightGray = Color(hex: "#E8E8EA")
    static let silver = Color(hex: "#C9CDD3")
    static let darkSilver = Color(hex: "#8F96A3")
    static let roseGold = Color(hex: "#B76E79")
    static let lightRoseGold = Color(hex: "#E6B7B2")
    static let warmRose = Color(hex: "#D99A9A")
    static let mutedText = Color(hex: "#A9A9B2")
    static let success = Color(hex: "#4FD18B")
    static let warning = Color(hex: "#E8B84F")
    static let danger = Color(hex: "#FF5A6A")

    // Semantic aliases
    static let background = productionBlack
    static let surface = softBlack
    static let surfaceElevated = Color(hex: "#1A1A1D")
    static let primaryText = offWhite
    static let secondaryText = mutedText
    static let accent = roseGold
    static let accentSoft = lightRoseGold
    static let stroke = Color(hex: "#242428")
}

