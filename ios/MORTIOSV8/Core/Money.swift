//
//  Money.swift
//  MORT iOS V8 — Core
//
//  Money is ALWAYS integer cents. Never Double, never Float, never client-side
//  financial truth. Formatting only — the backend owns every amount.
//

import Foundation

/// An amount in integer cents. Presentation-only helpers; no arithmetic
/// authority. The backend is the single source of financial truth.
///
/// `nonisolated` because money is pure data: it is decoded on background
/// threads and read from nonisolated model types.
nonisolated struct Money: Hashable, Sendable, Codable {
    /// Integer cents (int64). Negative values represent credits/refunds.
    let cents: Int64

    init(cents: Int64) { self.cents = cents }

    static let zero = Money(cents: 0)

    /// "$28.76" — standard display form.
    var formatted: String {
        Self.format(cents: cents)
    }

    /// "+$5.00" / "-$10.00" — signed display used in history rows.
    var signedFormatted: String {
        cents < 0 ? "-" + Self.format(cents: -cents) : "+" + Self.format(cents: cents)
    }

    /// "28.76" — bare numeric form for receipt columns.
    var bare: String {
        let abs = cents < 0 ? -cents : cents
        let whole = abs / 100
        let frac = abs % 100
        let grouped = Self.group(whole)
        return String(format: "%@.%02d", grouped, frac)
    }

    static func format(cents: Int64) -> String {
        let negative = cents < 0
        let abs = negative ? -cents : cents
        let whole = abs / 100
        let frac = abs % 100
        let body = String(format: "$%@.%02d", group(whole), frac)
        return negative ? "-\(body)" : body
    }

    /// Thousands grouping without relying on locale currency symbols.
    private static func group(_ value: Int64) -> String {
        let digits = String(value)
        guard digits.count > 3 else { return digits }
        var out = ""
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0, i % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return String(out.reversed())
    }
}

extension Money {
    /// Parses user input like "12", "12.5", "12.50" into cents.
    /// Returns nil for invalid input. Used by the custom tip field.
    static func parse(_ text: String) -> Money? {
        let cleaned = text.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        guard let whole = Int64(parts[0].isEmpty ? "0" : String(parts[0])), whole >= 0 else { return nil }
        var fracCents: Int64 = 0
        if parts.count == 2 {
            let fracText = String(parts[1])
            guard fracText.count <= 2, fracText.allSatisfy(\.isNumber) else { return nil }
            let padded = fracText.padding(toLength: 2, withPad: "0", startingAt: 0)
            guard let f = Int64(padded) else { return nil }
            fracCents = f
        }
        guard parts[0].allSatisfy(\.isNumber) || parts[0].isEmpty else { return nil }
        return Money(cents: whole * 100 + fracCents)
    }
}
