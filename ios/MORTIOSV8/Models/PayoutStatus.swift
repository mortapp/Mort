//
//  PayoutStatus.swift
//  MORT iOS V8 — Payment OS Models
//
//  PAYOUT SEPARATION (critical):
//  Payout status is visually and structurally SEPARATE from
//    (a) customer payment success,
//    (b) the teen earnings credit,
//    (c) the Connect transfer,
//    (d) the bank payout.
//
//  Payout status must NEVER be rendered inside an immutable receipt, and it
//  must never mutate one. Never fabricate payout completion.
//

import Foundation

nonisolated enum PayoutStage: String, Codable, Sendable, CaseIterable, Identifiable {
    /// The teen has not set up payouts yet.
    case setupRequired
    /// Provider (Connect) onboarding started but incomplete.
    case onboardingIncomplete
    /// Provider is verifying the account.
    case verificationPending
    /// Ready to receive transfers.
    case ready
    /// Platform -> connected account transfer in flight.
    case transferPending
    /// Transfer landed in the connected account balance.
    case transferComplete
    /// Bank payout initiated.
    case payoutPending
    /// Bank payout settled.
    case payoutPaid
    /// Provider restricted the account (needs action).
    case restricted
    /// Transfer or payout failed.
    case failed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .setupRequired: "PAYOUTS NOT SET UP"
        case .onboardingIncomplete: "SETUP INCOMPLETE"
        case .verificationPending: "VERIFICATION PENDING"
        case .ready: "READY FOR PAYOUTS"
        case .transferPending: "TRANSFER IN PROGRESS"
        case .transferComplete: "TRANSFERRED"
        case .payoutPending: "PAYOUT ON THE WAY"
        case .payoutPaid: "PAID TO BANK"
        case .restricted: "ACTION NEEDED"
        case .failed: "PAYOUT FAILED"
        }
    }

    var tone: MortTone {
        switch self {
        case .ready, .transferComplete, .payoutPaid: .success
        case .setupRequired, .onboardingIncomplete: .info
        case .verificationPending, .transferPending, .payoutPending: .warning
        case .restricted, .failed: .danger
        }
    }

    var symbol: String {
        switch self {
        case .setupRequired: "building.columns"
        case .onboardingIncomplete: "person.badge.clock"
        case .verificationPending: "hourglass"
        case .ready: "checkmark.shield"
        case .transferPending: "arrow.left.arrow.right"
        case .transferComplete: "tray.and.arrow.down"
        case .payoutPending: "clock.arrow.2.circlepath"
        case .payoutPaid: "checkmark.circle"
        case .restricted: "exclamationmark.shield"
        case .failed: "xmark.octagon"
        }
    }

    var guidance: String {
        switch self {
        case .setupRequired: "Set up payouts to move your earnings to a bank account."
        case .onboardingIncomplete: "Finish the payout setup so transfers can be sent."
        case .verificationPending: "Your provider is still verifying your details. Nothing else is needed from you right now."
        case .ready: "Earnings can be transferred out as jobs settle."
        case .transferPending: "MORT sent this to your payout account. It usually lands the same day."
        case .transferComplete: "The money is in your payout account balance."
        case .payoutPending: "Your bank payout is on its way. Banks usually take 1–2 business days."
        case .payoutPaid: "This landed in your bank account."
        case .restricted: "Your payout provider needs something from you before money can move."
        case .failed: "This transfer didn't go through. Your earnings are safe and still credited."
        }
    }

    /// True when the app must NOT imply money has reached the teen's bank.
    var isMoneyInBank: Bool { self == .payoutPaid }
}

/// Live payout state — lives in History / the payout panel, never on a receipt.
nonisolated struct PayoutStatus: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let stage: PayoutStage
    /// Amount this payout concerns, cents.
    let amountCents: Int64
    /// The earnings receipt this relates to (reference only — never mutates it).
    let relatedReceiptNumber: String?
    let updatedAt: Date
    /// Bank mask, e.g. "•••• 1881". Masked by the server.
    let destinationMask: String?
    let expectedText: String?

    var amount: Money { Money(cents: amountCents) }
}
