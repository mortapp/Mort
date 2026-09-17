//
//  HistoryComponents.swift
//  MORT iOS V8 — History Components
//
//  One chronological timeline that must stay readable past 100+ entries:
//  month grouping, result counts, signed monospaced amounts, and explicit
//  "no receipt issued" notes (icon + text, never colour alone).
//

import SwiftUI

/// Horizontally scrolling filter bar. Chips are 44pt tall.
struct HistoryFilterBar: View {
    let filters: [HistoryFilter]
    @Binding var selection: HistoryFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MortSpace.s2) {
                ForEach(filters) { filter in
                    MortChip(
                        label: filter.label,
                        isSelected: selection == filter
                    ) {
                        selection = filter
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        // Content margins instead of inner padding so there is no permanent
        // edge strip when the row is scrolled.
        .contentMargins(.horizontal, MortSpace.screen, for: .scrollContent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter history")
    }
}

/// Data-driven year picker. Years come from the feed — never hardcoded.
struct HistoryYearPicker: View {
    let years: [Int]
    @Binding var selection: Int?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MortSpace.s2) {
                MortChip(label: "All years", isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(years, id: \.self) { year in
                    MortChip(label: String(year), isSelected: selection == year) {
                        selection = year
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, MortSpace.screen, for: .scrollContent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by year")
    }
}

/// Month group header so long lists never read as one undifferentiated wall.
struct HistorySectionHeader: View {
    let title: String
    var count: Int?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(MortColor.textMuted)
            Spacer(minLength: MortSpace.s2)
            if let count {
                Text("\(count)")
                    .mortMicro()
            }
        }
        .padding(.top, MortSpace.s4)
        .padding(.bottom, MortSpace.s2)
        .accessibilityElement(children: .combine)
    }
}

/// One timeline row. Long titles ellipsize; the amount column is width-capped
/// so big values never push the layout.
struct HistoryRowView: View {
    let record: HistoryRecord
    let action: () -> Void

    var body: some View {
        Button {
            MortHaptic.tap()
            action()
        } label: {
            HStack(alignment: .top, spacing: MortSpace.s3) {
                ZStack {
                    Circle()
                        .fill(record.statusTone.dim)
                        .frame(width: 34, height: 34)
                    Image(systemName: record.kind.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(record.statusTone.color)
                }

                VStack(alignment: .leading, spacing: MortSpace.s1) {
                    Text(record.title)
                        .mortBodyStrong()
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: MortSpace.s2) {
                        Text(record.counterpartyHandle)
                            .mortMicro()
                            .lineLimit(1)
                        Text("·").mortMicro()
                        Text(record.dayText).mortMicro()
                    }
                    HStack(spacing: MortSpace.s2) {
                        MortStatusPill(
                            tone: record.statusTone,
                            symbol: record.statusSymbol,
                            label: record.statusLabel,
                            compact: true
                        )
                        if let order = record.orderNumber {
                            Text("#\(order)")
                                .font(MortFont.money(10))
                                .foregroundStyle(MortColor.textMuted)
                        }
                    }
                    if record.noReceiptIssued {
                        // Icon + text, never colour alone.
                        MortNote(
                            text: "No receipt issued",
                            tone: .neutral,
                            symbol: "doc.badge.ellipsis"
                        )
                    }
                }

                Spacer(minLength: MortSpace.s2)

                VStack(alignment: .trailing, spacing: MortSpace.s1) {
                    if record.amountCents != 0 {
                        Text(record.amount.signedFormatted)
                            .font(MortFont.money(14, weight: .medium))
                            .foregroundStyle(
                                record.amountCents < 0 ? MortColor.textSecondary : MortColor.success
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if record.receiptNumber != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MortColor.textMuted)
                    }
                }
                // Cap so long titles keep ellipsizing cleanly.
                .frame(maxWidth: 110, alignment: .trailing)
            }
            .padding(.vertical, MortSpace.s3)
            .frame(minHeight: MortMetric.minTouchTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(record.title), \(record.counterpartyHandle), \(record.statusLabel), \(record.amountCents == 0 ? "" : record.amount.signedFormatted)"
        )
        .accessibilityHint(record.receiptNumber != nil ? "Opens the receipt" : "")
    }
}

/// Search result count so users always know what they're looking at.
struct HistoryResultCount: View {
    let count: Int
    var query: String?

    var body: some View {
        HStack(spacing: MortSpace.s2) {
            Image(systemName: "list.bullet")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MortColor.textMuted)
            if let query, !query.isEmpty {
                Text("\(count) \(count == 1 ? "result" : "results") for \"\(query)\"")
                    .mortMicro()
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(count) \(count == 1 ? "record" : "records")")
                    .mortMicro()
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Annual export card. [DO NOT FAKE] — no generated file means no success.
struct ExportHistoryCard: View {
    let year: Int
    let state: ExportState
    var detail: String?
    var onStart: () -> Void
    var onSave: () -> Void
    var onRetry: () -> Void

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortSectionHeader(title: "Annual summary", subtitle: "\(year) activity")

                MortStatusPanel(
                    tone: state.tone,
                    symbol: state.symbol,
                    label: state.label,
                    detail: detail ?? defaultDetail
                )

                switch state {
                case .ready:
                    MortPrimaryButton(title: "Create \(year) summary", symbol: "square.and.arrow.down", action: onStart)
                case .preparing:
                    MortPrimaryButton(
                        title: "Preparing…",
                        isBusy: true,
                        busyTitle: "Preparing…",
                        action: {}
                    )
                case .readyToSave:
                    MortPrimaryButton(title: "Save file", symbol: "square.and.arrow.down", action: onSave)
                case .failed:
                    MortGhostButton(title: "Try again", symbol: "arrow.clockwise", action: onRetry)
                }

                MortNote(
                    text: "This is a summary of your MORT activity. It is not a tax document.",
                    tone: .warning,
                    symbol: "exclamationmark.circle"
                )
            }
        }
    }

    private var defaultDetail: String {
        switch state {
        case .ready: "We'll put your \(year) jobs, payments and receipts into one file."
        case .preparing: "We're building your file. This can take a moment."
        case .readyToSave: "Your file is ready to save to this device."
        case .failed: "We couldn't build the file. Nothing was saved."
        }
    }
}
