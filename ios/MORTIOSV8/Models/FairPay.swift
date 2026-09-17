//
//  FairPay.swift
//  MORT iOS V8 — Models
//
//  Fair Pay guardrail. The BACKEND owns the band and the hard minimum, and it
//  validates on submit. Disabling the POST button is UX, not security —
//  Swift client code is never the financial authority.
//
//  Tips are EXCLUDED from Fair Pay evaluation, always.
//

import Foundation

nonisolated enum FairPayZone: String, Codable, Sendable {
    case green
    case yellow
    case red

    var tone: MortTone {
        switch self {
        case .green: .success
        case .yellow: .warning
        case .red: .danger
        }
    }

    var symbol: String {
        switch self {
        case .green: "checkmark.seal"
        case .yellow: "exclamationmark.circle"
        case .red: "xmark.octagon"
        }
    }

    var title: String {
        switch self {
        case .green: "FAIR PAY"
        case .yellow: "BELOW RECOMMENDED"
        case .red: "PAYMENT IS TOO LOW FOR THIS WORK"
        }
    }
}

/// Backend-provided policy for a job type. CONFIGURABLE.
nonisolated struct FairPayPolicy: Codable, Hashable, Sendable {
    /// Bottom of the recommended band, cents.
    let recommendedLowCents: Int64
    /// Top of the recommended band, cents.
    let recommendedHighCents: Int64
    /// Hard minimum below which posting is blocked, cents.
    let hardMinimumCents: Int64
    let jobTypeLabel: String

    /// Reference policy used for previews only.
    static let reference = FairPayPolicy(
        recommendedLowCents: 2000,
        recommendedHighCents: 2800,
        hardMinimumCents: 1400,
        jobTypeLabel: "Yard work · ~2 hours"
    )

    var recommendedLow: Money { Money(cents: recommendedLowCents) }
    var recommendedHigh: Money { Money(cents: recommendedHighCents) }
    var hardMinimum: Money { Money(cents: hardMinimumCents) }

    var bandText: String {
        "\(recommendedLow.formatted)–\(recommendedHigh.formatted)"
    }
}

/// The verdict the UI renders for an offer. Mirrors backend policy; the
/// backend re-validates every submission.
nonisolated struct FairPayVerdict: Sendable, Equatable {
    let zone: FairPayZone
    let title: String
    let body: String
    /// False blocks the posting CTA (UX guard only).
    let canPost: Bool

    static func evaluate(offeredCents: Int64, policy: FairPayPolicy) -> FairPayVerdict {
        if offeredCents < policy.hardMinimumCents {
            return .init(
                zone: .red,
                title: FairPayZone.red.title,
                body: "For \(policy.jobTypeLabel), most people offer \(policy.bandText). This job can't be posted under \(policy.hardMinimum.formatted). Raise the offer to continue.",
                canPost: false
            )
        }
        if offeredCents < policy.recommendedLowCents {
            return .init(
                zone: .yellow,
                title: FairPayZone.yellow.title,
                body: "You can post this, but \(policy.bandText) gets far more applicants for \(policy.jobTypeLabel).",
                canPost: true
            )
        }
        return .init(
            zone: .green,
            title: FairPayZone.green.title,
            body: "This is in line with what people pay for \(policy.jobTypeLabel).",
            canPost: true
        )
    }
}
