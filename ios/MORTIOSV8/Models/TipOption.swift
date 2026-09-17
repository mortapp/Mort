//
//  TipOption.swift
//  MORT iOS V8 — Payment OS Models
//
//  TIP RULES (all mandatory):
//   - Tipping is optional.
//   - 100% of the tip goes to the teen.
//   - MORT's percentage fee on a tip is ZERO.
//   - Tips are EXCLUDED from Fair Pay.
//   - A tip is a SEPARATE provider transaction.
//   - A failed tip does NOT undo a successful base settlement.
//   - A late tip is represented as its own separate receipt.
//

import Foundation

nonisolated enum TipOption: Identifiable, Hashable, Sendable {
    case none
    case flat(Int64)          // cents
    case percent(Int)         // 10, 15, 20
    case custom

    var id: String {
        switch self {
        case .none: "none"
        case .flat(let c): "flat-\(c)"
        case .percent(let p): "pct-\(p)"
        case .custom: "custom"
        }
    }

    var label: String {
        switch self {
        case .none: "No tip"
        case .flat(let c): Money(cents: c).formatted
        case .percent(let p): "\(p)%"
        case .custom: "Custom"
        }
    }

    /// The exact selector order approved for MORT.
    static let standard: [TipOption] = [
        .none,
        .flat(200),
        .flat(500),
        .flat(1000),
        .percent(10),
        .percent(15),
        .percent(20),
        .custom,
    ]

    /// Display-only projection of a percentage chip against base pay.
    /// The charged amount always comes from the backend tip intent.
    func previewCents(baseCents: Int64) -> Int64? {
        switch self {
        case .none: 0
        case .flat(let c): c
        case .percent(let p): baseCents * Int64(p) / 100
        case .custom: nil
        }
    }
}

/// Backend-owned tip limits. CONFIGURABLE.
nonisolated struct TipConfig: Codable, Hashable, Sendable {
    let minimumCents: Int64
    let maximumCents: Int64

    static let reference = TipConfig(minimumCents: 100, maximumCents: 5000)

    var minimum: Money { Money(cents: minimumCents) }
    var maximum: Money { Money(cents: maximumCents) }
}

/// Validation states for the custom tip field.
nonisolated enum CustomTipValidation: Equatable, Sendable {
    case empty
    case valid(Money)
    case tooLow(TipConfig)
    case tooHigh(TipConfig)
    case invalid

    var message: String? {
        switch self {
        case .empty: nil
        case .valid: nil
        case .tooLow(let c): "The smallest tip is \(c.minimum.formatted)."
        case .tooHigh(let c): "Tips are capped at \(c.maximum.formatted) here."
        case .invalid: "Enter an amount like 7.50."
        }
    }

    var tone: MortTone {
        switch self {
        case .empty: .neutral
        case .valid: .success
        case .tooLow, .tooHigh, .invalid: .danger
        }
    }

    var money: Money? {
        if case .valid(let m) = self { return m }
        return nil
    }

    static func evaluate(_ text: String, config: TipConfig) -> CustomTipValidation {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .empty }
        guard let money = Money.parse(trimmed) else { return .invalid }
        if money.cents < config.minimumCents { return .tooLow(config) }
        if money.cents > config.maximumCents { return .tooHigh(config) }
        return .valid(money)
    }
}
