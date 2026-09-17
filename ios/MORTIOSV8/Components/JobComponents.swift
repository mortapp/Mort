//
//  JobComponents.swift
//  MORT iOS V8 — Job Components
//

import SwiftUI

/// Job card used in discovery and job lists.
struct JobCard: View {
    let job: MortJob
    var showsState: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            MortHaptic.tap()
            action()
        } label: {
            MortCard {
                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    HStack(alignment: .top, spacing: MortSpace.s3) {
                        VStack(alignment: .leading, spacing: MortSpace.s1) {
                            Text(job.title)
                                .mortTitle()
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(job.category) · \(job.distance)")
                                .mortMicro()
                                .lineLimit(1)
                        }
                        Spacer(minLength: MortSpace.s2)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(job.basePay.formatted)
                                .font(MortFont.money(18, weight: .medium))
                                .foregroundStyle(MortColor.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("BASE PAY")
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(MortColor.textMuted)
                        }
                        .frame(maxWidth: 110, alignment: .trailing)
                    }

                    MortDivider()

                    HStack(spacing: MortSpace.s3) {
                        HStack(spacing: MortSpace.s1 + 2) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundStyle(MortColor.textMuted)
                            Text(job.scheduleText)
                                .mortMicro()
                                .lineLimit(1)
                        }
                        Spacer(minLength: MortSpace.s2)
                        if showsState {
                            MortStatusPill(
                                tone: job.state.tone,
                                symbol: job.state.symbol,
                                label: job.state.label,
                                compact: true
                            )
                        } else {
                            Text(job.postedAgo)
                                .mortMicro()
                                .lineLimit(1)
                        }
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(job.title), \(job.basePay.formatted) base pay, \(job.category), \(job.distance)")
        .accessibilityHint("Opens job details")
    }
}

/// Compact job context strip — messages and payments always show which job
/// they belong to.
struct JobContextStrip: View {
    let title: String
    var orderNumber: String?
    var counterpartyHandle: String?

    var body: some View {
        HStack(spacing: MortSpace.s2) {
            Image(systemName: "briefcase")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MortColor.silver1)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MortColor.textPrimary)
                    .lineLimit(1)
                if let counterpartyHandle {
                    Text(counterpartyHandle).mortMicro().lineLimit(1)
                }
            }
            Spacer(minLength: MortSpace.s2)
            if let orderNumber {
                Text("#\(orderNumber)")
                    .font(MortFont.money(11))
                    .foregroundStyle(MortColor.textMuted)
            }
        }
        .padding(.horizontal, MortSpace.s3)
        .padding(.vertical, MortSpace.s2 + 2)
        .background {
            RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                .fill(MortColor.graphite2.opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                .strokeBorder(MortColor.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Applicant row used by the adult's applicant list.
struct ApplicantRow: View {
    let application: MortApplication
    var onOpen: () -> Void
    var onSelect: (() -> Void)?

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                HStack(spacing: MortSpace.s3) {
                    MortAvatar(
                        initials: String(application.applicantDisplayName.prefix(2)).uppercased(),
                        size: 40
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(application.applicantDisplayName)
                            .mortBodyStrong()
                            .lineLimit(1)
                        HStack(spacing: MortSpace.s2) {
                            Text(application.applicantHandle).mortMicro().lineLimit(1)
                            if let rating = application.applicantRating {
                                Text("·").mortMicro()
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Text(String(format: "%.1f", rating))
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(MortColor.silver2)
                            }
                            Text("·").mortMicro()
                            Text("\(application.applicantCompletedJobs) jobs").mortMicro()
                        }
                    }
                    Spacer(minLength: MortSpace.s2)
                    MortStatusPill(
                        tone: application.state.tone,
                        symbol: application.state.symbol,
                        label: application.state.label,
                        compact: true
                    )
                }

                Text(application.message)
                    .mortBody()
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: MortSpace.s2) {
                    MortGhostButton(title: "View profile", action: onOpen)
                    if let onSelect {
                        MortPrimaryButton(title: "Choose", action: onSelect)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Rating stars with an explicit numeric value (never stars alone).
struct MortRatingView: View {
    let rating: Double?
    let completedJobs: Int

    var body: some View {
        HStack(spacing: MortSpace.s2) {
            if let rating, completedJobs > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < rating.rounded() ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundStyle(MortColor.silver2)
                    }
                }
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MortColor.textPrimary)
                Text("(\(completedJobs) jobs)")
                    .mortMicro()
            } else {
                Text("No ratings yet")
                    .mortMicro()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            rating == nil || completedJobs == 0
                ? "No ratings yet"
                : "Rated \(String(format: "%.1f", rating ?? 0)) out of 5 from \(completedJobs) jobs"
        )
    }
}

/// Payout status panel. Lives OUTSIDE the immutable receipt, always.
struct PayoutStatusPanel: View {
    let payout: PayoutStatus
    var onSetUp: (() -> Void)?

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortSectionHeader(title: "Payout status", subtitle: "Live — updates as money moves")

                MortStatusPanel(
                    tone: payout.stage.tone,
                    symbol: payout.stage.symbol,
                    label: payout.stage.label,
                    detail: payout.stage.guidance
                )

                VStack(spacing: MortSpace.s2) {
                    MortKeyValueRow(
                        label: "AMOUNT",
                        value: payout.amount.formatted,
                        isMonospaced: true
                    )
                    if let mask = payout.destinationMask {
                        MortKeyValueRow(label: "DESTINATION", value: mask, isMonospaced: true)
                    }
                    if let expected = payout.expectedText {
                        MortKeyValueRow(label: "EXPECTED", value: expected)
                    }
                }

                MortNote(
                    text: "Payout status is separate from your earnings receipt. The receipt never changes when a payout moves.",
                    tone: .info,
                    symbol: "lock.doc"
                )

                if payout.stage == .setupRequired || payout.stage == .onboardingIncomplete,
                   let onSetUp {
                    MortPrimaryButton(title: "Set up payouts", action: onSetUp)
                }
            }
        }
    }
}
