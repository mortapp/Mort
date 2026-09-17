//
//  MortSettingsStore.swift
//  MORT iOS V8 — Core
//
//  Local, non-sensitive preferences. Never store credentials or financial
//  data here — credentials belong in the Keychain.
//

import SwiftUI

@Observable
final class MortSettingsStore {
    private let defaults = UserDefaults.standard

    /// Fully animated atmosphere (stars, clouds, meteors, shimmer).
    var animatedBackground: Bool {
        didSet { defaults.set(animatedBackground, forKey: Keys.animatedBackground) }
    }

    /// In-app reduced motion: static atmosphere, no handwriting intro.
    var reducedMotion: Bool {
        didSet { defaults.set(reducedMotion, forKey: Keys.reducedMotion) }
    }

    var notifyJobs: Bool {
        didSet { defaults.set(notifyJobs, forKey: Keys.notifyJobs) }
    }

    var notifyMessages: Bool {
        didSet { defaults.set(notifyMessages, forKey: Keys.notifyMessages) }
    }

    var notifyPayments: Bool {
        didSet { defaults.set(notifyPayments, forKey: Keys.notifyPayments) }
    }

    var safetyReminders: Bool {
        didSet { defaults.set(safetyReminders, forKey: Keys.safetyReminders) }
    }

    /// Whether the launch wordmark intro already played this session.
    var wordmarkPlayed: Bool = false

    init() {
        // Read straight from the store: a helper method can't be called
        // before every stored property is initialized.
        let store = UserDefaults.standard
        animatedBackground = store.object(forKey: Keys.animatedBackground) as? Bool ?? true
        reducedMotion = store.object(forKey: Keys.reducedMotion) as? Bool ?? false
        notifyJobs = store.object(forKey: Keys.notifyJobs) as? Bool ?? true
        notifyMessages = store.object(forKey: Keys.notifyMessages) as? Bool ?? true
        notifyPayments = store.object(forKey: Keys.notifyPayments) as? Bool ?? true
        safetyReminders = store.object(forKey: Keys.safetyReminders) as? Bool ?? true
    }

    private enum Keys {
        static let animatedBackground = "mort.animatedBackground"
        static let reducedMotion = "mort.reducedMotion"
        static let notifyJobs = "mort.notifyJobs"
        static let notifyMessages = "mort.notifyMessages"
        static let notifyPayments = "mort.notifyPayments"
        static let safetyReminders = "mort.safetyReminders"
    }
}
