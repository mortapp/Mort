//
//  PayoutAndExportViews.swift
//  MORT iOS V8 — History / Financial
//
//  Payout status, payout setup, annual export, earnings overview and the
//  financial-safety guide.
//
//  Payout completion is NEVER fabricated, and the export never reports
//  success without a real file.
//

import SwiftUI

struct PayoutStatusView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var current: LoadState<PayoutStatus> = .idle
    @State private var history: [PayoutStatus] = []
    @State private var isRefreshing = false

    var body: some View {
        MortScreen(
            title: "Payouts",
            subtitle: "Money moving from MORT to your bank.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                switch current {
                case .idle, .loading:
                    MortSkeletonList(rows: 3)
                case .failed(let error):
                    MortErrorState(message: error.userMessage) { Task { await load() } }
                case .loaded(let payout), .offlineCache(let payout):
                    PayoutStatusPanel(payout: payout) {
                        nav.push(.payoutSetup)
                    }

                    if payout.stage == .setupRequired || payout.stage == .onboardingIncomplete {
                        MortStatusPanel(
                            tone: .info,
                            symbol: "info.circle",
                            label: "YOUR EARNINGS ARE SAFE",
                            detail: "Even without payouts set up, everything you earn is recorded and credited. Setting up payouts just tells us where to send it."
                        )
                    }
                }

                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "Past payouts")
                        MortCard {
                            VStack(spacing: 0) {
                                ForEach(Array(history.enumerated()), id: \.element.id) { index, payout in
                                    HStack(spacing: MortSpace.s3) {
                                        Image(systemName: payout.stage.symbol)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(payout.stage.tone.color)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(payout.amount.formatted)
                                                .font(MortFont.money(14, weight: .medium))
                                                .foregroundStyle(MortColor.textPrimary)
                                            if let mask = payout.destinationMask {
                                                Text(mask).mortMicro()
                                            }
                                        }
                                        Spacer(minLength: MortSpace.s2)
                                        MortStatusPill(
                                            tone: payout.stage.tone,
                                            symbol: payout.stage.symbol,
                                            label: payout.stage.label,
                                            compact: true
                                        )
                                    }
                                    .padding(.vertical, MortSpace.s2)
                                    if index < history.count - 1 { MortDivider() }
                                }
                            }
                        }
                    }
                }

                MortNote(
                    text: "Payout status never changes an earnings receipt. Receipts record what you earned; payouts record where it went.",
                    tone: .neutral,
                    symbol: "lock.doc"
                )
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "Refresh status",
                    symbol: "arrow.clockwise",
                    isBusy: isRefreshing
                ) {
                    Task { await refresh() }
                }
            }
        }
        .navigationTitle("Payouts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        current = .loading
        do {
            current = .loaded(try await mort.payouts.payoutStatus())
            history = (try? await mort.payouts.payoutHistory()) ?? []
        } catch let error as MortError {
            current = .failed(error)
        } catch {
            current = .failed(.unknown)
        }
    }

    private func refresh() async {
        isRefreshing = true
        // Readiness is re-read from the provider via the backend — never
        // assumed from a local action.
        _ = try? await mort.payouts.refreshPayoutReadiness()
        await load()
        isRefreshing = false
    }
}

struct PayoutSetupView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var isWorking = false
    @State private var error: MortError?
    @State private var launched = false

    var body: some View {
        MortScreen(
            title: "Set up payouts",
            subtitle: "Tell MORT where to send your earnings.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error {
                    MortStatusPanel(
                        tone: .danger,
                        symbol: "exclamationmark.triangle",
                        label: "COULDN'T START SETUP",
                        detail: error.userMessage
                    )
                }

                if launched {
                    MortStatusPanel(
                        tone: .warning,
                        symbol: "hourglass",
                        label: "FINISH IN YOUR BROWSER",
                        detail: "Complete the steps with our payout provider, then come back and refresh. MORT only marks you ready once the provider confirms it."
                    )
                }

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "What you'll need")
                        MortNote(text: "Your bank account details.", tone: .neutral, symbol: "building.columns")
                        MortNote(text: "A guardian's help if you're under 18.", tone: .neutral, symbol: "person.2")
                        MortNote(text: "A few minutes — the provider verifies your details.", tone: .neutral, symbol: "clock")
                    }
                }

                MortNote(
                    text: "MORT never sees or stores your bank details. Our payout provider handles that directly.",
                    tone: .info,
                    symbol: "lock.shield"
                )
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: launched ? "Refresh my status" : "Start payout setup",
                    symbol: launched ? "arrow.clockwise" : "arrow.up.forward.app",
                    isBusy: isWorking
                ) {
                    Task { launched ? await refresh() : await start() }
                }
                MortQuietButton(title: "Not now") { nav.pop() }
            }
        }
        .navigationTitle("Payout setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func start() async {
        isWorking = true
        error = nil
        do {
            let url = try await mort.payouts.beginPayoutOnboarding()
            #if canImport(UIKit)
            await UIApplication.shared.open(url)
            #endif
            launched = true
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }

    private func refresh() async {
        isWorking = true
        _ = try? await mort.payouts.refreshPayoutReadiness()
        isWorking = false
        nav.pop()
    }
}

struct AnnualExportView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var year = Calendar.current.component(.year, from: Date()) - 1
    @State private var state: ExportState = .ready
    @State private var years: [Int] = []
    @State private var error: MortError?
    @State private var shareURL: URL?

    var body: some View {
        MortScreen(
            title: "Annual summary",
            subtitle: "One file with a year of jobs, payments and receipts.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error {
                    MortStatusPanel(
                        tone: .danger,
                        symbol: "exclamationmark.triangle",
                        label: "EXPORT PROBLEM",
                        detail: error.userMessage
                    )
                }

                if !years.isEmpty {
                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text("YEAR").mortEyebrow()
                        ScrollView(.horizontal) {
                            HStack(spacing: MortSpace.s2) {
                                ForEach(years, id: \.self) { value in
                                    MortChip(label: String(value), isSelected: year == value) {
                                        year = value
                                        Task { await refreshState() }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                ExportHistoryCard(
                    year: year,
                    state: state
                ) {
                    Task { await start() }
                } onSave: {
                    Task { await save() }
                } onRetry: {
                    Task { await start() }
                }

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "What's inside")
                        MortNote(text: "Every job, with dates and who you worked with.", tone: .neutral, symbol: "briefcase")
                        MortNote(text: "Every payment, tip, refund and adjustment.", tone: .neutral, symbol: "creditcard")
                        MortNote(text: "Receipt numbers so anything can be looked up.", tone: .neutral, symbol: "doc.text")
                    }
                }

                MortStatusPanel(
                    tone: .warning,
                    symbol: "exclamationmark.circle",
                    label: "NOT A TAX DOCUMENT",
                    detail: "This is a summary of your MORT activity to help you keep records. It isn't tax or legal advice, and it isn't an official tax form."
                )
            }
        }
        .navigationTitle("Annual summary")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            years = (try? await mort.history.availableYears()) ?? [year]
            await refreshState()
        }
        .sheet(item: Binding(
            get: { shareURL.map(ExportFile.init(url:)) },
            set: { if $0 == nil { shareURL = nil } }
        )) { file in
            ShareSheet(items: [file.url])
        }
    }

    private func refreshState() async {
        state = (try? await mort.history.exportState(year: year)) ?? .ready
    }

    private func start() async {
        error = nil
        state = .preparing
        do {
            try await mort.history.startAnnualExport(year: year)
            // Poll for the backend's real state — never assume completion.
            for _ in 0..<12 {
                try? await Task.sleep(for: .seconds(1))
                let latest = try await mort.history.exportState(year: year)
                state = latest
                if latest != .preparing { break }
            }
        } catch let failure as MortError {
            error = failure
            state = .failed
        } catch {
            state = .failed
        }
    }

    private func save() async {
        error = nil
        do {
            // [DO NOT FAKE] No file from the backend ⇒ no success state.
            shareURL = try await mort.history.exportFile(year: year)
            MortHaptic.success()
        } catch let failure as MortError {
            error = failure
            state = .failed
            MortHaptic.failure()
        } catch {
            state = .failed
        }
    }
}

private struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Earnings overview — financial safety surface for teens.
struct EarningsView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var records: LoadState<[HistoryRecord]> = .idle
    @State private var payout: PayoutStatus?

    private var earnings: [HistoryRecord] {
        (records.value ?? []).filter { $0.kind == .earning || $0.kind == .tip }
    }

    private var totalCents: Int64 {
        earnings.reduce(0) { $0 + max(0, $1.amountCents) }
    }

    var body: some View {
        MortScreen(
            title: "Your earnings",
            subtitle: "What you've earned on MORT, and where it is.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                switch records {
                case .idle, .loading:
                    MortSkeletonList(rows: 4)
                case .failed(let error):
                    MortErrorState(message: error.userMessage) { Task { await load() } }
                case .loaded, .offlineCache:
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s2) {
                            Text("TOTAL EARNED").mortEyebrow()
                            Text(Money(cents: totalCents).formatted)
                                .font(MortFont.money(38, weight: .light))
                                .foregroundStyle(MortColor.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text("Across \(earnings.count) \(earnings.count == 1 ? "payment" : "payments")")
                                .mortMicro()
                        }
                    }

                    if let payout {
                        PayoutStatusPanel(payout: payout) {
                            nav.push(.payoutSetup)
                        }
                    }

                    if earnings.isEmpty {
                        MortEmptyState(
                            symbol: "chart.line.uptrend.xyaxis",
                            title: "No earnings yet",
                            message: "Finish your first job and it shows up here."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            MortSectionHeader(title: "Recent")
                            ForEach(earnings.prefix(8)) { record in
                                HistoryRowView(record: record) {
                                    if let number = record.receiptNumber {
                                        nav.push(.receipt(number))
                                    }
                                }
                                MortDivider()
                            }
                        }
                    }

                    VStack(spacing: MortSpace.s2) {
                        MortGhostButton(title: "Full history", symbol: "clock.arrow.circlepath") {
                            nav.push(.history)
                        }
                        MortGhostButton(title: "Money basics", symbol: "book") {
                            nav.push(.financialGuide)
                        }
                    }
                }
            }
        }
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        records = .loading
        do {
            let page = try await mort.history.records(
                filter: .all, year: nil, query: nil, cursor: nil
            )
            records = .loaded(page.records)
            payout = try? await mort.payouts.payoutStatus()
        } catch let error as MortError {
            records = .failed(error)
        } catch {
            records = .failed(.unknown)
        }
    }
}

/// Educational guidance. Deliberately NOT presented as tax or legal authority.
struct FinancialGuideView: View {
    var body: some View {
        MortScreen(
            title: "Money basics",
            subtitle: "Plain-language guidance — not tax or legal advice.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                GuideCard(
                    symbol: "hand.thumbsup",
                    title: "You keep 100% of tips",
                    detail: "MORT never takes a percentage of a tip. Tips are on top of your base pay, and they're always the poster's choice."
                )
                GuideCard(
                    symbol: "percent",
                    title: "MORT's fee isn't yours",
                    detail: "The service fee is added on top of what the poster pays. It never comes out of your earnings."
                )
                GuideCard(
                    symbol: "lock.shield",
                    title: "Money is held before you work",
                    detail: "A job can't start until it's funded. If someone asks you to work before that, say no and report it."
                )
                GuideCard(
                    symbol: "building.columns",
                    title: "Earning isn't the same as being paid out",
                    detail: "Your earnings are credited when a job settles. The bank transfer happens after that, and it can take a couple of days."
                )
                GuideCard(
                    symbol: "doc.text",
                    title: "Keep your records",
                    detail: "Every payment has a receipt, and you can export a year at a time. Depending on where you live and how much you earn, you may need these."
                )

                MortStatusPanel(
                    tone: .warning,
                    symbol: "exclamationmark.circle",
                    label: "THIS ISN'T TAX ADVICE",
                    detail: "MORT gives you records and plain explanations. For anything about taxes or your specific situation, talk to a guardian or a qualified professional."
                )
            }
        }
        .navigationTitle("Money basics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GuideCard: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        MortCard {
            HStack(alignment: .top, spacing: MortSpace.s3) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MortColor.silver1)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: MortSpace.s1) {
                    Text(title).mortBodyStrong()
                    Text(detail)
                        .mortBody()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Payouts") {
    NavigationStack { PayoutStatusView() }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}

#Preview("Annual export") {
    NavigationStack { AnnualExportView() }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
