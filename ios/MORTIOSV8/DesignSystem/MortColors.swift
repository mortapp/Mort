//
//  MortColors.swift
//  MORT iOS V8 — Design System
//
//  Canonical MORT palette, ported 1:1 from the approved MORT color system.
//
//  Visual balance target:
//  70-80% black / near-black, 10-15% graphite, 7-12% silver/white,
//  2-6% midnight blue atmospheric depth, <1% icy-blue highlight.
//
//  Never reintroduce: rose gold as primary, pink-heavy UI, emerald-heavy UI,
//  purple gradients, generic glassmorphism everywhere.
//

import SwiftUI

/// The MORT palette. Use these semantic values; never hardcode colors in views.
enum MortColor {
    // ---- Primary black ----
    static let black = Color(hex: 0x000000)
    static let ink1 = Color(hex: 0x010101)
    static let ink2 = Color(hex: 0x030405)
    static let ink3 = Color(hex: 0x050607)

    // ---- Soft black / graphite ----
    static let graphite1 = Color(hex: 0x080A0D)
    static let graphite2 = Color(hex: 0x0B0D11)
    static let graphite3 = Color(hex: 0x101218)
    static let graphite4 = Color(hex: 0x14171D)

    // ---- Midnight blue depth (atmosphere only, not UI paint) ----
    static let night1 = Color(hex: 0x020818)
    static let night2 = Color(hex: 0x061020)
    static let night3 = Color(hex: 0x0A1930)
    static let night4 = Color(hex: 0x0C2140)

    // ---- Silver ----
    static let silver1 = Color(hex: 0xBFC3CA)
    static let silver2 = Color(hex: 0xCBD0D7)
    static let silver3 = Color(hex: 0xD6DAE0)
    static let silver4 = Color(hex: 0xE1E4E8)

    // ---- Bright silver / ice ----
    static let ice1 = Color(hex: 0xE9EDF2)
    static let ice2 = Color(hex: 0xF2F5F8)
    static let ice3 = Color(hex: 0xF7F9FB)
    static let white = Color(hex: 0xFFFFFF)

    // ---- Text ----
    static let textPrimary = Color(hex: 0xF7F8FA)
    static let textSecondary = Color(hex: 0xADB2BA)
    static let textMuted = Color(hex: 0x707680)

    // ---- Borders ----
    static let borderGraphite = Color(hex: 0x1A1D23)
    static let borderGraphite2 = Color(hex: 0x23272F)
    static let borderSilver = Color(hex: 0x555C67)

    // ---- Very subtle cold blue light (sparingly) ----
    static let blueLight1 = Color(hex: 0x13284A)
    static let blueLight2 = Color(hex: 0x183865)
    static let blueLight3 = Color(hex: 0x204B7F)

    // ---- Semantic status ----
    /// Status color is NEVER used alone: always tone + icon + text.
    static let danger = Color(hex: 0xE5484D)
    static let dangerDeep = Color(hex: 0x7F2B2E)
    static let success = Color(hex: 0x4DBD8A)
    static let warning = Color(hex: 0xD9A94F)
    static let info = Color(hex: 0x8FB4D9)

    // ---- Pre-mixed surfaces (black glass / smoked glass) ----
    static let cardBg = Color(hex: 0x050609, alpha: 0.75)
    static let cardBg2 = Color(hex: 0x080A0D, alpha: 0.80)
    static let cardBg3 = Color(hex: 0x0B0D11, alpha: 0.82)
    static let hairline = Color(hex: 0xE1E4E8, alpha: 0.06)
    static let hairline2 = Color(hex: 0xD6DAE0, alpha: 0.10)
    static let blueHairline = Color(hex: 0x788CAA, alpha: 0.08)

    // ---- Atmosphere stars ----
    static let star = Color(hex: 0xCDD5DE)
    static let starCold = Color(hex: 0xAEB8C4)
    static let starIce = Color(hex: 0xE5EBF1)
    static let starBlue = Color(hex: 0x9FC0E8)

    // ---- Receipt paper (Payment OS) ----
    /// Receipts are warm off-white paper inside the dark shell — never a dark card.
    static let paper = Color(hex: 0xF3F0E7)
    static let paperEdge = Color(hex: 0xDDD8C9)
    static let paperInk = Color(hex: 0x191D22)
    static let paperInkSoft = Color(hex: 0x4E5560)
    static let paperRule = Color(hex: 0xC9C3B2)

    // ---- Status tint fills (dim backgrounds behind status text) ----
    static let successDim = Color(hex: 0x4DBD8A, alpha: 0.13)
    static let dangerDim = Color(hex: 0xE5484D, alpha: 0.12)
    static let warningDim = Color(hex: 0xD9A94F, alpha: 0.13)
    static let infoDim = Color(hex: 0x8FB4D9, alpha: 0.12)
    static let neutralDim = Color(hex: 0x707680, alpha: 0.14)
}

extension Color {
    /// Creates a color from a 0xRRGGBB literal with optional alpha.
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// Semantic tone used by every status surface in the app.
/// A tone NEVER travels alone — it always carries an icon and a label.
enum MortTone: String, Codable, Sendable, CaseIterable {
    case success, danger, warning, info, neutral

    var color: Color {
        switch self {
        case .success: MortColor.success
        case .danger: MortColor.danger
        case .warning: MortColor.warning
        case .info: MortColor.info
        case .neutral: MortColor.textSecondary
        }
    }

    var dim: Color {
        switch self {
        case .success: MortColor.successDim
        case .danger: MortColor.dangerDim
        case .warning: MortColor.warningDim
        case .info: MortColor.infoDim
        case .neutral: MortColor.neutralDim
        }
    }

    /// Ink-on-paper variant for receipt surfaces.
    var paperColor: Color {
        switch self {
        case .success: Color(hex: 0x2C7A55)
        case .danger: Color(hex: 0xA33B39)
        case .warning: Color(hex: 0x8A6420)
        case .info: Color(hex: 0x3B5A7A)
        case .neutral: MortColor.paperInkSoft
        }
    }
}
