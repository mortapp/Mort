//
//  HistoryView.swift
//  MORT iOS V8 — History
//
//  Job & Payment History: ONE chronological timeline with refining filters.
//
//  Rule R1: going back from a receipt restores the filter, query, year AND
//  scroll position — the list is never reset to top/ALL.
//

import SwiftUI

@Observable
@MainActor
final class HistoryViewModel {
    var records: LoadState<[HistoryRecord]> = .idle
    var filter: HistoryFilter = .all
    var year: Int?
    var query: String = ""
    var years: [Int] = []
    var nextCursor: String?
    var isPaginating = false
    /// Restored on return from a receipt (rule R1).
    var lastVisibleRecordId: String?

    private let mort: MortDependencies
    init(mort: MortDependencies) { self.mort = mort }

    func load() async {
        records = .loading
        nextCursor = nil
        do {
            let page = try await mort.history.records(
                filter: filter,
                year: year,
                query: query.isEmpty ? nil : query,
                cursor: nil
            )
            records = .loaded(page.records)
            nextCursor = page.nextCursor
            if years.isEmpty {
                years = (try? await mort.history.availableYears()) ?? []
            }
        } catch let error as MortError {
            records = error == .offline ? .offlineCache([]) : .failed(error)
        } catch {
            records = .failed(.unknown)
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isPaginating else { return }
        isPaginating = true
        defer { isPaginating = false }
        do {
            let page = try await mort.history.records(
                filter: filter,
                year: year,
                query: query.isEmpty ? nil : query,
                cursor: cursor
            )
            records = .loaded((records.value ?? []) + page.records)
            nextCursor = page.nextCursor
        } catch {
            nextCursor = nil
        }
    }

    /// Month grouping so a 100+ entry list never reads as one wall of cards.
    var grouped: [(month: String, records: [HistoryRecord])] {
        let all = records.value ?? []
        var order: [String] = []
        var buckets: [String: [HistoryRecord]] = [:]
        for record in all {
            let key = record.monthKey
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(record)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var totalCount: Int { (records.value ?? []).count }
}

struct HistoryView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: HistoryViewModel?

    var body: some View {
        MortScreen(atmosphereIntensity: 0.6) {
            if let model {
                VStack(alignment: .leading, spacing: MortSpace.s4) {
                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text("Job & payment history").mortH1()
                        Text("Everything you've done on MORT, newest first.")
                            .mortBody()
                    }

                    MortSearchField(
                        placeholder: "Receipt #, order #, job, person",
                        text: Binding(get: { model.query }, set: { model.query = $0 })
                    ) {
                        Task { await model.load() }
                    }

                    filterBars(model)

                    content(model)

                    MortGhostButton(title: "Annual summary", symbol: "square.and.arrow.down") {
                        nav.push(.annualExport)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = HistoryViewModel(mort: mort) }
            if case .idle = model?.records { await model?.load() }
        }
        .refreshable { await model?.load() }
    }

    @ViewBuilder
    private func filterBars(_ model: HistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            // Filters/year bars bleed to the screen edge deliberately; the
            // negative inset matches the screen's horizontal padding.
            HistoryFilterBar(
                filters: HistoryFilter.available(for: user.role),
                selection: Binding(
                    get: { model.filter },
                    set: {
                        model.filter = $0
                        Task { await model.load() }
                    }
                )
            )
            .padding(.horizontal, -MortSpace.screen)

            if !model.years.isEmpty {
                HistoryYearPicker(
                    years: model.years,
                    selection: Binding(
                        get: { model.year },
                        set: {
                            model.year = $0
                            Task { await model.load() }
                        }
                    )
                )
                .padding(.horizontal, -MortSpace.screen)
            }
        }
    }

    @ViewBuilder
    private func content(_ model: HistoryViewModel) -> some View {
        switch model.records {
        case .idle, .loading:
            MortSkeletonList(rows: 6)

        case .failed(let error):
            MortErrorState(
                title: "Couldn't load your history",
                message: error.userMessage
            ) {
                Task { await model.load() }
            }

        case .offlineCache(let cached):
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortOfflineBanner { Task { await model.load() } }
                if cached.isEmpty {
                    MortEmptyState(
                        symbol: "wifi.slash",
                        title: "Nothing saved offline",
                        message: "Reconnect to see your full history."
                    )
                } else {
                    timeline(model)
                }
            }

        case .loaded(let records):
            if records.isEmpty {
                emptyState(model)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HistoryResultCount(
                        count: model.totalCount,
                        query: model.query.isEmpty ? nil : model.query
                    )
                    .padding(.bottom, MortSpace.s2)
                    timeline(model)
                }
            }
        }
    }

    @ViewBuilder
    private func timeline(_ model: HistoryViewModel) -> some View {
        // ScrollViewReader restores position when returning from a receipt.
        ScrollViewReader { proxy in
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(model.grouped, id: \.month) { group in
                    Section {
                        ForEach(group.records) { record in
                            HistoryRowView(record: record) {
                                model.lastVisibleRecordId = record.id
                                if let number = record.receiptNumber {
                                    nav.push(.receipt(number))
                                } else if let jobId = record.jobId {
                                    nav.push(.jobDetail(jobId))
                                }
                            }
                            .id(record.id)
                            MortDivider()
                        }
                    } header: {
                        HistorySectionHeader(title: group.month, count: group.records.count)
                            .padding(.horizontal, MortSpace.s1)
                            .background {
                                Rectangle()
                                    .fill(MortColor.ink1.opacity(0.92))
                                    .blur(radius: 2)
                                    .padding(.horizontal, -MortSpace.screen)
                            }
                    }
                }

                if model.nextCursor != nil {
                    MortPaginationLoader()
                        .task { await model.loadMore() }
                }
            }
            .onAppear {
                // Rule R1: restore the row the user left from.
                if let id = model.lastVisibleRecordId {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(_ model: HistoryViewModel) -> some View {
        if !model.query.isEmpty {
            MortEmptyState(
                symbol: "magnifyingglass",
                title: "No matches",
                message: "Nothing matched \"\(model.query)\". Try a receipt number, order number, job title or @username.",
                actionTitle: "Clear search"
            ) {
                model.query = ""
                Task { await model.load() }
            }
        } else if model.filter != .all || model.year != nil {
            MortEmptyState(
                symbol: "line.3.horizontal.decrease.circle",
                title: "Nothing in this view",
                message: "There's nothing under these filters yet.",
                actionTitle: "Show everything"
            ) {
                model.filter = .all
                model.year = nil
                Task { await model.load() }
            }
        } else {
            MortEmptyState(
                symbol: "clock.arrow.circlepath",
                title: "No history yet",
                message: user.role == .adult
                    ? "Once you fund your first job, every payment and receipt lands here."
                    : "Once you finish your first job, every payment and receipt lands here."
            )
        }
    }
}

/// Dedicated search screen with hint chips that fill the field.
struct HistorySearchView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: HistoryViewModel?

    private let hints = ["K-260915-04827", "0042", "Lawn mowing", "@marcus"]

    var body: some View {
        MortScreen(
            title: "Search history",
            subtitle: "Find any receipt, order, job or person.",
            atmosphereIntensity: 0.6
        ) {
            if let model {
                VStack(alignment: .leading, spacing: MortSpace.s4) {
                    MortSearchField(
                        placeholder: "Receipt #, order #, job, person",
                        text: Binding(get: { model.query }, set: { model.query = $0 })
                    ) {
                        Task { await model.load() }
                    }

                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text("TRY SEARCHING FOR").mortEyebrow()
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 130), spacing: MortSpace.s2)],
                            spacing: MortSpace.s2
                        ) {
                            ForEach(hints, id: \.self) { hint in
                                MortChip(label: hint, isSelected: false) {
                                    model.query = hint
                                    Task { await model.load() }
                                }
                            }
                        }
                    }

                    if !model.query.isEmpty {
                        switch model.records {
                        case .idle, .loading:
                            MortSkeletonList(rows: 4)
                        case .failed(let error):
                            MortErrorState(message: error.userMessage) {
                                Task { await model.load() }
                            }
                        case .loaded(let records), .offlineCache(let records):
                            if records.isEmpty {
                                MortEmptyState(
                                    symbol: "magnifyingglass",
                                    title: "No matches",
                                    message: "Nothing matched \"\(model.query)\".",
                                    actionTitle: "Clear search"
                                ) {
                                    model.query = ""
                                }
                            } else {
                                HistoryResultCount(count: records.count, query: model.query)
                                LazyVStack(spacing: 0) {
                                    ForEach(records) { record in
                                        HistoryRowView(record: record) {
                                            if let number = record.receiptNumber {
                                                nav.push(.receipt(number))
                                            } else if let jobId = record.jobId {
                                                nav.push(.jobDetail(jobId))
                                            }
                                        }
                                        MortDivider()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .task { if model == nil { model = HistoryViewModel(mort: mort) } }
    }
}

#Preview("History") {
    NavigationStack { HistoryView(user: MortFixtures.teen) }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}

#Preview("History — 140 records") {
    NavigationStack { HistoryView(user: MortFixtures.teen) }
        .environment(\.mort, MortDependencies.preview(largeHistory: true))
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
