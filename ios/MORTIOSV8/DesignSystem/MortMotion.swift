//
//  MortMotion.swift
//  MORT iOS V8 — Design System
//
//  Premium, restrained motion. Every animation has a static equivalent that
//  preserves the same MEANING when Reduce Motion is enabled — motion never
//  carries information on its own.
//

import SwiftUI

enum MortMotion {
    static let fast: Double = 0.14
    static let medium: Double = 0.26
    static let slow: Double = 0.42

    /// Standard entrance/exit curve.
    static var ease: Animation { .timingCurve(0.22, 1, 0.36, 1, duration: medium) }
    static var easeFast: Animation { .timingCurve(0.22, 1, 0.36, 1, duration: fast) }
    static var easeSlow: Animation { .timingCurve(0.22, 1, 0.36, 1, duration: slow) }

    /// Calm confirmation spring (success states). Never bouncy/celebratory.
    static var confirm: Animation { .spring(response: 0.48, dampingFraction: 0.86) }
    /// Press feedback spring.
    static var press: Animation { .spring(response: 0.26, dampingFraction: 0.72) }

    /// Returns the animation, or nil when the user asked for reduced motion.
    static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// Resolved motion preference: the OS setting OR the in-app MORT setting.
struct MortReducedMotionKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True when animation must be suppressed (OS Reduce Motion or MORT setting).
    var mortReducedMotion: Bool {
        get { self[MortReducedMotionKey.self] }
        set { self[MortReducedMotionKey.self] = newValue }
    }
}

extension View {
    /// Applies an animation only when motion is allowed.
    func mortAnimation<V: Equatable>(_ animation: Animation, value: V, reduced: Bool) -> some View {
        self.animation(reduced ? nil : animation, value: value)
    }
}
