//
//  MortHaptics.swift
//  MORT iOS V8 — Design System
//
//  Restrained native haptics. Financial confirmations get a single decisive
//  tap — never a celebratory burst.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum MortHaptic {
    /// Light tap for selection (chips, tabs, list rows).
    static func select() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// Button press impact.
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Confirmed, backend-verified success (funding confirmed, receipt issued).
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Serious but recoverable failure (declined, error).
    static func failure() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    /// Caution (fair-pay red, destructive confirmation).
    static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
