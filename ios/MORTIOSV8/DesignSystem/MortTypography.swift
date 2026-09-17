//
//  MortTypography.swift
//  MORT iOS V8 — Design System
//
//  Quiet, confident, premium: light weights for large headings, precise
//  labels, generous letter spacing. All styles support Dynamic Type through
//  relative font sizing.
//

import SwiftUI

enum MortFont {
    /// Large brand display type (onboarding, entry, empty heroes).
    static func display() -> Font { .system(size: 40, weight: .light, design: .default) }
    static func h1() -> Font { .system(size: 30, weight: .light) }
    static func h2() -> Font { .system(size: 22, weight: .regular) }
    static func title() -> Font { .system(size: 16, weight: .medium) }
    static func body() -> Font { .system(size: 15, weight: .regular) }
    static func bodyStrong() -> Font { .system(size: 15, weight: .medium) }
    static func label() -> Font { .system(size: 13, weight: .medium) }
    /// Uppercase eyebrow labels with wide tracking.
    static func eyebrow() -> Font { .system(size: 11, weight: .medium) }
    static func micro() -> Font { .system(size: 12, weight: .regular) }
    static func button() -> Font { .system(size: 15, weight: .medium) }

    /// Monospaced money type. Money is ALWAYS monospaced and tabular so
    /// columns of currency align on every receipt and breakdown.
    static func money(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// Display heading.
    func mortDisplay() -> some View {
        font(MortFont.display())
            .tracking(1.5)
            .foregroundStyle(MortColor.textPrimary)
    }

    func mortH1() -> some View {
        font(MortFont.h1())
            .tracking(0.8)
            .foregroundStyle(MortColor.textPrimary)
    }

    func mortH2() -> some View {
        font(MortFont.h2())
            .tracking(0.2)
            .foregroundStyle(MortColor.textPrimary)
    }

    func mortTitle() -> some View {
        font(MortFont.title())
            .foregroundStyle(MortColor.textPrimary)
    }

    func mortBody() -> some View {
        font(MortFont.body())
            .foregroundStyle(MortColor.textSecondary)
    }

    func mortBodyStrong() -> some View {
        font(MortFont.bodyStrong())
            .foregroundStyle(MortColor.textPrimary)
    }

    func mortLabel() -> some View {
        font(MortFont.label())
            .foregroundStyle(MortColor.textSecondary)
    }

    /// Uppercase tracked eyebrow. Pass already-uppercased text.
    func mortEyebrow() -> some View {
        font(MortFont.eyebrow())
            .tracking(3)
            .foregroundStyle(MortColor.textMuted)
    }

    func mortMicro() -> some View {
        font(MortFont.micro())
            .foregroundStyle(MortColor.textMuted)
    }
}
