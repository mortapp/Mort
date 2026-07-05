//
//  JobsFeedView.swift
//  MORT
//

import SwiftUI

struct JobsFeedView: View {
    @Environment(\.services) private var services
    @State private var jobs: [Job] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var selectedCategory: JobCategory?

    private var filtered: [Job] {
        guard let selectedCategory else { return jobs }
        return jobs.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "Safe jobs", subtitle: "Browse local hustles near you")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MortSpacing.xs) {
                        CategoryChip(label: "All", selected: selectedCategory == nil) { selectedCategory = nil }
                        ForEach(JobCategory.allCases) { cat in
                            CategoryChip(label: cat.label, systemImage: cat.systemImage, selected: selectedCategory == cat) {
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, MortSpacing.md)
                }
                .padding(.vertical, MortSpacing.xs)

                content
            }
            .mortScreen()
            .navigationDestination(for: Job.self) { JobDetailView(job: $0) }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView(label: "Finding safe jobs…")
        } else if let errorMessage {
            MortErrorView(message: errorMessage) { Task { await load() } }
        } else if filtered.isEmpty {
            MortEmptyState(systemImage: "tray", title: "No safe jobs are available yet.", message: "Check back soon — new local hustles show up here.")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(filtered) { job in
                        NavigationLink(value: job) {
                            MortJobCard(job: job)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            jobs = try await services.jobs.fetchJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

struct CategoryChip: View {
    let label: String
    var systemImage: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .semibold)) }
                Text(label).font(MortFont.caption())
            }
            .foregroundStyle(selected ? MortColor.productionBlack : MortColor.silver)
            .padding(.horizontal, MortSpacing.sm)
            .padding(.vertical, 8)
            .background(selected ? AnyShapeStyle(MortColor.roseGold) : AnyShapeStyle(MortColor.surface))
            .clipShape(.rect(cornerRadius: MortRadius.pill))
            .overlay(
                RoundedRectangle(cornerRadius: MortRadius.pill).stroke(MortColor.stroke, lineWidth: selected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
