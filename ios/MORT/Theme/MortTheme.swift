//
//  MortTheme.swift
//  MORT
//
//  Typography, spacing, radius, and shared view modifiers.
//

import SwiftUI

enum MortSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum MortRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let pill: CGFloat = 999
}

enum MortFont {
    static func largeTitle() -> Font { .system(size: 34, weight: .bold, design: .rounded) }
    static func title() -> Font { .system(size: 26, weight: .bold, design: .rounded) }
    static func title2() -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
    static func headline() -> Font { .system(size: 17, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 16, weight: .regular, design: .rounded) }
    static func callout() -> Font { .system(size: 15, weight: .medium, design: .rounded) }
    static func caption() -> Font { .system(size: 13, weight: .regular, design: .rounded) }
    static func tiny() -> Font { .system(size: 11, weight: .semibold, design: .rounded) }
    /// Wordmark used in splash and top bars.
    static func wordmark() -> Font { .system(size: 44, weight: .heavy, design: .rounded) }
}

/// A full-bleed dark background that establishes the MORT atmosphere.
struct MortBackground: View {
    var body: some View {
        ZStack {
            MortColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [MortColor.roseGold.opacity(0.16), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 520
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [MortColor.softBlack.opacity(0.9), Color.clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 480
            )
            .ignoresSafeArea()
        }
    }
}

extension View {
    /// Standard MORT screen container: dark background + safe horizontal padding.
    func mortScreen() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(MortBackground())
    }

    /// Card surface styling.
    func mortSurface(cornerRadius: CGFloat = MortRadius.md) -> some View {
        self
            .background(MortColor.surface)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(MortColor.stroke, lineWidth: 1)
            )
    }
}
