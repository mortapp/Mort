//
//  MortMetrics.swift
//  MORT iOS V8 — Design System
//
//  Spacing (8pt grid), radii, borders, and hard accessibility minimums.
//

import SwiftUI

enum MortSpace {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let s10: CGFloat = 40

    /// Standard screen horizontal margin.
    static let screen: CGFloat = 16
}

enum MortRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 22
    static let pill: CGFloat = 999
}

enum MortMetric {
    /// Hard accessibility floor for every interactive control.
    static let minTouchTarget: CGFloat = 44
    static let hairlineWidth: CGFloat = 1
    static let controlHeight: CGFloat = 52
    static let rowHeight: CGFloat = 64
}

extension View {
    /// Enforces the 44pt minimum interactive target in both axes.
    func mortTouchTarget() -> some View {
        frame(minWidth: MortMetric.minTouchTarget, minHeight: MortMetric.minTouchTarget)
    }

    /// Standard screen horizontal padding.
    func mortScreenPadding() -> some View {
        padding(.horizontal, MortSpace.screen)
    }

    /// Hairline stroke used on graphite surfaces.
    func mortHairlineBorder(radius: CGFloat = MortRadius.lg, color: Color = MortColor.hairline2) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: MortMetric.hairlineWidth)
        }
    }
}
