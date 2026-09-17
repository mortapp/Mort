//
//  MortError.swift
//  MORT iOS V8 — Core
//
//  Error mapping. Internal detail NEVER reaches the user; every error is
//  mapped to safe, honest copy.
//

import Foundation

nonisolated enum MortError: Error, Equatable, Sendable {
    case offline
    case timeout
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverUnavailable
    /// Backend rejected the request with a safe, user-facing reason.
    case rejected(String)
    /// A payment-specific failure, already mapped to the safe catalog.
    case payment(PaymentFailureReason)
    /// Capability genuinely unavailable on this device/build.
    case capabilityUnavailable(String)
    /// The integration point is not wired yet. Fails CLOSED: the UI shows an
    /// honest unavailable state and never a fabricated success.
    case notConfigured(String)
    case unknown

    /// Safe, user-facing message. No internal codes, no stack detail.
    var userMessage: String {
        switch self {
        case .offline:
            "You're offline. Check your connection and try again."
        case .timeout:
            "That took too long. Please try again."
        case .unauthorized:
            "Please sign in again to continue."
        case .forbidden:
            "You don't have access to this."
        case .notFound:
            "We couldn't find that."
        case .rateLimited:
            "Too many tries. Please wait a moment."
        case .serverUnavailable:
            "MORT is temporarily unavailable. Please try again shortly."
        case .rejected(let reason):
            reason
        case .payment(let reason):
            reason.title
        case .capabilityUnavailable(let what):
            "\(what) isn't available on this device."
        case .notConfigured(let what):
            "\(what) isn't connected in this build yet."
        case .unknown:
            "Something went wrong. It's not something you did."
        }
    }

    /// True when retrying could plausibly succeed.
    var isRetryable: Bool {
        switch self {
        case .offline, .timeout, .serverUnavailable, .rateLimited, .unknown: true
        case .unauthorized, .forbidden, .notFound, .rejected, .payment,
             .capabilityUnavailable, .notConfigured: false
        }
    }
}

/// Generic async loading state used by every ViewModel.
nonisolated enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(MortError)
    /// Loaded, but from a local cache while offline.
    case offlineCache(Value)

    var value: Value? {
        switch self {
        case .loaded(let v), .offlineCache(let v): v
        case .idle, .loading, .failed: nil
        }
    }

    var error: MortError? {
        if case .failed(let e) = self { return e }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isOffline: Bool {
        if case .offlineCache = self { return true }
        return false
    }
}
