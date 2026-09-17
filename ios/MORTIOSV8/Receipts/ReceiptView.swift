//
//  ReceiptView.swift
//  MORT iOS V8 — Receipts
//
//  The single typed receipt screen. Every document category (adult payment,
//  teen earnings, store purchase, late tip, full refund, partial refund,
//  adjustment, reversal) renders through `ReceiptDocumentView`.
//
//  Receipts are IMMUTABLE. This screen renders a backend-issued document and
//  never mutates it. Payout status is NOT shown here — it lives in History.
//

import SwiftUI

struct ReceiptView: View {
    let receiptNumber: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var receipt: LoadState<Receipt> = .idle

    var body: some View {
        MortScreen(atmosphereIntensity: 0.5) {
            switch receipt {
            case .idle, .loading:
                VStack(spacing: MortSpace.s4) {
                    Text("Loading your receipt…").mortBody()
                    MortSkeletonBar(height: 420, radius: 4)
                }
            case .failed:
                // A failed fetch NEVER fabricates a document.
                ReceiptUnavailableInline(receiptNumber: receiptNumber) {
                    Task { await load() }
                } onSupport: {
                    nav.push(.receiptSupportReference(receiptNumber))
                }
            case .loaded(let document), .offlineCache(let document):
                VStack(spacing: MortSpace.s5) {
                    ReceiptDocumentView(receipt: document)

                    if document.type == .teenEarnings {
                        // Payout state lives OUTSIDE the immutable receipt.
                        MortGhostButton(title: "View payout status", symbol: "building.columns") {
                            nav.push(.payoutSeparation(document.id))
                        }
                    }

                    MortNote(
                        text: "This receipt can't change. Refunds, adjustments and tips create their own linked documents.",
                        tone: .neutral,
                        symbol: "lock.doc"
                    )
                }
            }
        } bottom: {
            if let document = receipt.value {
                MortBottomBar {
                    MortPrimaryButton(title: "Share or save", symbol: "square.and.arrow.up") {
                        nav.present(.receiptActions(document.id))
                    }
                    MortQuietButton(title: "Copy receipt number for support") {
                        nav.push(.receiptSupportReference(document.id))
                    }
                }
            }
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        receipt = .loading
        do {
            receipt = .loaded(try await mort.receipts.receipt(number: receiptNumber))
        } catch let error as MortError {
            receipt = .failed(error)
        } catch {
            receipt = .failed(.unknown)
        }
    }
}

/// Inline unavailable state used when a receipt fetch fails.
struct ReceiptUnavailableInline: View {
    let receiptNumber: String
    let onRetry: () -> Void
    let onSupport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s5) {
            MortStatusPanel(
                tone: .warning,
                symbol: "doc.badge.ellipsis",
                label: "RECEIPT UNAVAILABLE",
                detail: "We couldn't load this receipt right now. Your record is safe — this is a display problem, not a money problem."
            )

            MortCard {
                MortCopyRow(label: "Receipt #", value: receiptNumber)
            }

            VStack(spacing: MortSpace.s2) {
                MortPrimaryButton(title: "Try again", symbol: "arrow.clockwise", action: onRetry)
                MortGhostButton(title: "Contact support", symbol: "headphones", action: onSupport)
            }
        }
    }
}

struct ReceiptUnavailableView: View {
    let receiptNumber: String

    @Environment(MortNavigator.self) private var nav

    var body: some View {
        MortScreen(
            title: "Receipt unavailable",
            atmosphereIntensity: 0.55
        ) {
            ReceiptUnavailableInline(receiptNumber: receiptNumber) {
                nav.pop()
            } onSupport: {
                nav.push(.receiptSupportReference(receiptNumber))
            }
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Share / save / print / copy. [DO NOT FAKE] — each action uses the real
/// system affordance, and unsupported actions are visibly disabled.
struct ReceiptActionsView: View {
    let receiptNumber: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(\.dismiss) private var dismiss
    @State private var receipt: Receipt?
    @State private var shareItem: String?

    var body: some View {
        MortScreen(
            title: "Receipt actions",
            subtitle: "Keep a copy for your records.",
            atmosphereIntensity: 0.55
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortCard {
                    VStack(spacing: 0) {
                        MortNavRow(
                            title: "Share",
                            detail: "Send it through the iOS share sheet",
                            symbol: "square.and.arrow.up"
                        ) {
                            shareItem = shareText
                        }
                        MortDivider()
                        MortNavRow(
                            title: "Save to Files",
                            detail: "Store a copy on this device",
                            symbol: "folder"
                        ) {
                            shareItem = shareText
                        }
                        MortDivider()
                        MortNavRow(
                            title: "Print",
                            detail: "Send to an AirPrint printer",
                            symbol: "printer"
                        ) {
                            shareItem = shareText
                        }
                        MortDivider()
                        MortNavRow(
                            title: "Copy receipt number",
                            detail: receiptNumber,
                            symbol: "doc.on.doc"
                        ) {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = receiptNumber
                            #endif
                            MortHaptic.success()
                        }
                    }
                }

                MortNote(
                    text: "Shared copies show usernames and masked references only — never full names or card numbers.",
                    tone: .info,
                    symbol: "lock.shield"
                )
            }
        }
        .navigationTitle("Actions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                    nav.dismissSheet()
                }
                .foregroundStyle(MortColor.silver3)
            }
        }
        .task {
            receipt = try? await mort.receipts.receipt(number: receiptNumber)
        }
        .sheet(item: Binding(
            get: { shareItem.map(SharePayload.init(text:)) },
            set: { if $0 == nil { shareItem = nil } }
        )) { payload in
            ShareSheet(items: [payload.text])
        }
    }

    private var shareText: String {
        guard let receipt else { return "MORT receipt \(receiptNumber)" }
        let lines = receipt.lines.map { line in
            line.amount.map { "\(line.label): \($0.formatted)" } ?? line.label
        }
        return """
        MORT — \(receipt.type.documentTitle)
        Order #\(receipt.orderNumber)
        Receipt #\(receipt.id)
        \(receipt.issuedAtText)

        \(receipt.serviceTitle)
        \(lines.joined(separator: "\n"))

        \(receipt.statusLabel)
        """
    }
}

private struct SharePayload: Identifiable {
    let text: String
    var id: String { text }
}

/// Native share sheet bridge.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Support reference: the copyable identifiers support will ask for.
struct ReceiptSupportReferenceView: View {
    let receiptNumber: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var receipt: Receipt?

    var body: some View {
        MortScreen(
            title: "Support reference",
            subtitle: "Copy these when you contact us — it's the fastest way to get help.",
            atmosphereIntensity: 0.55
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortCard {
                    VStack(spacing: MortSpace.s2) {
                        MortCopyRow(label: "Receipt #", value: receiptNumber)
                        if let receipt {
                            MortDivider()
                            MortCopyRow(label: "Order #", value: receipt.orderNumber)
                            MortDivider()
                            MortCopyRow(label: "Issued", value: receipt.issuedAtText)
                        }
                    }
                }

                MortNote(
                    text: "MORT support will never ask for your full card number, password, or a verification code.",
                    tone: .warning,
                    symbol: "exclamationmark.shield"
                )
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(title: "Contact support", symbol: "headphones") {
                    nav.push(.supportNewCase(topicId: "payment", reference: receiptNumber))
                }
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            receipt = try? await mort.receipts.receipt(number: receiptNumber)
        }
    }
}

/// Demonstrates the separation rule: the immutable earnings receipt on one
/// side, the LIVE payout status on the other. Payout changes never mutate the
/// receipt.
struct PayoutSeparationView: View {
    let receiptNumber: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var receipt: Receipt?
    @State private var payout: PayoutStatus?

    var body: some View {
        MortScreen(
            title: "Earnings vs payout",
            subtitle: "Two different things — here's how they relate.",
            atmosphereIntensity: 0.55
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(
                        title: "1. Your earnings receipt",
                        subtitle: "Permanent record — never changes"
                    )
                    if let receipt {
                        ReceiptDocumentView(receipt: receipt)
                    } else {
                        MortSkeletonBar(height: 300, radius: 4)
                    }
                }

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(
                        title: "2. Your payout status",
                        subtitle: "Live — changes as money moves"
                    )
                    if let payout {
                        PayoutStatusPanel(payout: payout) {
                            nav.push(.payoutSetup)
                        }
                    } else {
                        MortSkeletonList(rows: 2)
                    }
                }

                MortStatusPanel(
                    tone: .info,
                    symbol: "arrow.left.arrow.right",
                    label: "WHY THEY'RE SEPARATE",
                    detail: "Your receipt records what you earned the moment the job settled. The payout is the bank transfer that follows. If a transfer is delayed or retried, your earnings record stays exactly the same."
                )
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(title: "See all payouts", symbol: "building.columns") {
                    nav.push(.payoutStatus)
                }
                MortQuietButton(title: "Back to receipt") { nav.pop() }
            }
        }
        .navigationTitle("Earnings & payout")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            receipt = try? await mort.receipts.receipt(number: receiptNumber)
            payout = try? await mort.payouts.payoutStatus()
        }
    }
}

#Preview("Adult receipt") {
    NavigationStack {
        ReceiptView(receiptNumber: MortFixtures.adultReceipt.id)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}

#Preview("Teen earnings receipt") {
    NavigationStack {
        ReceiptView(receiptNumber: MortFixtures.teenReceipt.id)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}

#Preview("Partial refund") {
    NavigationStack {
        ReceiptView(receiptNumber: MortFixtures.partialRefundReceipt.id)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
