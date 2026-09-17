//
//  DiscoverView.swift
//  MORT iOS V8 — Jobs
//
//  Job discovery with search, category filters and cursor pagination.
//

import SwiftUI

@Observable
@MainActor
final class DiscoverViewModel {
    var jobs: LoadState<[MortJob]> = .idle
    var query = ""
    var category: String?
    var nextCursor: String?
    var isPaginating = false

    private let mort: MortDependencies
    init(mort: MortDependencies) { self.mort = mort }

    func load() async {
        jobs = .loading
        nextCursor = nil
        do {
            let page = try await mort.jobs.discover(
                query: query.isEmpty ? nil : query,
                category: category,
                cursor: nil
            )
            jobs = .loaded(page.jobs)
            nextCursor = page.nextCursor
        } catch let error as MortError {
            jobs = .failed(error)
        } catch {
            jobs = .failed(.unknown)
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isPaginating else { return }
        isPaginating = true
        defer { isPaginating = false }
        do {
            let page = try await mort.jobs.discover(
                query: query.isEmpty ? nil : query,
                category: category,
                cursor: cursor
            )
            jobs = .loaded((jobs.value ?? []) + page.jobs)
            nextCursor = page.nextCursor
        } catch {
            nextCursor = nil
        }
    }
}

struct DiscoverView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: DiscoverViewModel?

    var body: some View {
        MortScreen(atmosphereIntensity: 0.8) {
            if let model {
                VStack(alignment: .leading, spacing: MortSpace.s4) {
                    MortSearchField(
                        placeholder: "Search jobs near you",
                        text: Binding(get: { model.query }, set: { model.query = $0 })
                    ) {
                        Task { await model.load() }
                    }

                    categoryRow(model)

                    switch model.jobs {
                    case .idle, .loading:
                        MortSkeletonList(rows: 5)
                    case .failed(let error):
                        MortErrorState(message: error.userMessage) {
                            Task { await model.load() }
                        }
                    case .loaded(let jobs), .offlineCache(let jobs):
                        if jobs.isEmpty {
                            MortEmptyState(
                                symbol: "magnifyingglass",
                                title: model.query.isEmpty ? "No jobs nearby yet" : "No matches",
                                message: model.query.isEmpty
                                    ? "New jobs show up as neighbors post them. Turn on job alerts so you hear first."
                                    : "Try a different search, or clear the filters."
                            )
                        } else {
                            HistoryResultCount(count: jobs.count, query: model.query.isEmpty ? nil : model.query)
                            ForEach(jobs) { job in
                                JobCard(job: job) { nav.push(.jobDetail(job.id)) }
                            }
                            if model.nextCursor != nil {
                                MortPaginationLoader()
                                    .task { await model.loadMore() }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Find work")
        .task {
            if model == nil { model = DiscoverViewModel(mort: mort) }
            if case .idle = model?.jobs { await model?.load() }
        }
        .refreshable { await model?.load() }
    }

    @ViewBuilder
    private func categoryRow(_ model: DiscoverViewModel) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: MortSpace.s2) {
                MortChip(label: "All", isSelected: model.category == nil) {
                    model.category = nil
                    Task { await model.load() }
                }
                ForEach(MortFixtures.categories, id: \.self) { category in
                    MortChip(label: category, isSelected: model.category == category) {
                        model.category = model.category == category ? nil : category
                        Task { await model.load() }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Job categories")
    }
}

#Preview {
    NavigationStack { DiscoverView() }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
