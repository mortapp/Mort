import SwiftUI

struct JobFeedView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var jobs: [Job] = []
    @State private var savedIDs: Set<UUID> = []
    @State private var filters = JobSearchFilters()
    @State private var page = 0
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingFilters = false

    var body: some View {
        Group {
            if isLoading && jobs.isEmpty {
                VStack(spacing: MortSpacing.md) {
                    ForEach(0..<5, id: \.self) { _ in
                        MortCard { VStack(spacing: MortSpacing.sm) { MortSkeleton(height: 18); MortSkeleton(height: 30); MortSkeleton(height: 16) } }
                    }
                }
                .padding(MortSpacing.lg)
            } else if let errorMessage, jobs.isEmpty {
                MortErrorState(message: errorMessage) { Task { await reload() } }
            } else if jobs.isEmpty {
                MortEmptyState(title: "No jobs match", message: "Try a broader search or fewer filters.", systemImage: "magnifyingglass")
            } else {
                ScrollView {
                    LazyVStack(spacing: MortSpacing.sm) {
                        ForEach(jobs) { job in
                            JobCardView(job: job, isSaved: savedIDs.contains(job.id)) {
                                Task { await toggleSaved(job.id) }
                            }
                            .onTapGesture { router.push(.jobDetail(job.id)) }
                            .onAppear {
                                if job.id == jobs.last?.id, hasMore, !isLoading { Task { await loadNextPage() } }
                            }
                        }
                        MortBannerPlacement(placement: "job_feed")
                        if isLoading { ProgressView().tint(MortColors.neon).padding() }
                    }
                    .padding(.horizontal, MortSpacing.lg)
                    .padding(.bottom, MortSpacing.xl)
                }
                .refreshable { await reload() }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { searchBar }
        .navigationTitle("Local jobs")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { router.push(.savedJobs) } label: { Image(systemName: "bookmark.fill") }
                    .accessibilityLabel("Saved jobs")
                Button { router.push(.notifications) } label: { Image(systemName: "bell") }
                    .accessibilityLabel("Notifications")
            }
        }
        .sheet(isPresented: $showingFilters) { JobFilterSheet(filters: $filters) { Task { await reload() } } }
        .task { if jobs.isEmpty { await reload() } }
        .task(id: filters.keyword) {
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            await reload()
        }
        .mortScreen()
    }

    private var searchBar: some View {
        HStack(spacing: MortSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(MortColors.textMuted)
            TextField("Search jobs", text: $filters.keyword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button { showingFilters = true } label: {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundStyle(hasFilters ? MortColors.neon : MortColors.textMuted)
            }
            .accessibilityLabel("Job filters")
        }
        .padding(MortSpacing.sm)
        .background(MortColors.elevated)
        .overlay(alignment: .bottom) { Rectangle().fill(MortColors.line).frame(height: 1) }
    }

    private var hasFilters: Bool {
        filters.category != nil || filters.minimumPayCents != nil || filters.paymentType != nil ||
            filters.scheduleType != nil || filters.verificationRequirement != nil || filters.requiresGuardianApproval != nil
    }

    private func reload() async {
        page = 0
        hasMore = true
        jobs = []
        await loadNextPage()
        do { savedIDs = Set(try await container.savedJobs.list().map(\.id)) }
        catch { savedIDs = [] }
    }

    private func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = try await container.jobs.listOpen(filters: filters, page: page, pageSize: 20)
            jobs.append(contentsOf: next.filter { incoming in !jobs.contains(where: { $0.id == incoming.id }) })
            hasMore = next.count == 20
            if hasMore { page += 1 }
            errorMessage = nil
        } catch {
            errorMessage = mortMessage(error)
        }
    }

    private func toggleSaved(_ jobID: UUID) async {
        do {
            if savedIDs.contains(jobID) {
                try await container.savedJobs.remove(jobID: jobID)
                savedIDs.remove(jobID)
            } else {
                try await container.savedJobs.save(jobID: jobID)
                savedIDs.insert(jobID)
            }
        } catch { errorMessage = mortMessage(error) }
    }
}

struct JobCardView: View {
    let job: Job
    let isSaved: Bool
    let toggleSaved: () -> Void

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack {
                    MortBadge(text: job.category, tint: MortColors.safetyBlue)
                    if job.posterVerified { MortBadge(text: "Verified", tint: MortColors.neon) }
                    Spacer()
                    Button(action: toggleSaved) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(isSaved ? MortColors.neon : MortColors.textMuted)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? "Remove saved job" : "Save job")
                }
                Text(job.title).font(MortTypography.section)
                if let summary = job.summary?.nilIfBlank {
                    Text(summary).font(MortTypography.body).foregroundStyle(MortColors.textMuted).lineLimit(2)
                }
                HStack {
                    Label(job.payDisplay, systemImage: "dollarsign.circle.fill").foregroundStyle(MortColors.neon)
                    Spacer()
                    Label(job.locationText, systemImage: "mappin.and.ellipse").foregroundStyle(MortColors.textMuted)
                }
                .font(MortTypography.caption)
                Label(job.scheduleDisplay, systemImage: "calendar").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                if job.requiresGuardianApproval {
                    Label("This job requires guardian approval", systemImage: "person.2.badge.gearshape")
                        .font(MortTypography.caption)
                        .foregroundStyle(MortColors.warning)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

private struct JobFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: JobSearchFilters
    let apply: () -> Void
    private let categories = ["All", "cleaning", "yard work", "pet care", "moving", "events", "tutoring", "tech help", "other"]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: Binding(get: { filters.category ?? "All" }, set: { filters.category = $0 == "All" ? nil : $0 })) {
                    ForEach(categories, id: \.self) { Text($0.capitalized).tag($0) }
                }
                Picker("Sort", selection: $filters.sort) {
                    ForEach(JobSort.allCases) { Text($0.title).tag($0) }
                }
                Picker("Minimum pay", selection: $filters.minimumPayCents) {
                    Text("Any").tag(Int?.none)
                    Text("$10+").tag(Int?.some(1_000))
                    Text("$25+").tag(Int?.some(2_500))
                    Text("$50+").tag(Int?.some(5_000))
                }
                Picker("Schedule", selection: $filters.scheduleType) {
                    Text("Any").tag(String?.none)
                    Text("Flexible").tag(String?.some("flexible"))
                    Text("Scheduled").tag(String?.some("scheduled"))
                }
                Picker("Guardian approval", selection: $filters.requiresGuardianApproval) {
                    Text("Any").tag(Bool?.none)
                    Text("Not required").tag(Bool?.some(false))
                    Text("Required").tag(Bool?.some(true))
                }
            }
            .scrollContentBackground(.hidden)
            .background(MortColors.background)
            .navigationTitle("Job filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { filters = JobSearchFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply(); dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SavedJobsView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var state: LoadState<[Job]> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading saved jobs")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(jobs) where jobs.isEmpty:
                MortEmptyState(title: "Nothing saved yet", message: "Bookmark a job to keep it here.", systemImage: "bookmark")
            case let .loaded(jobs):
                List {
                    ForEach(jobs) { job in
                        JobCardView(job: job, isSaved: true) { Task { await remove(job.id) } }
                            .listRowBackground(MortColors.background)
                            .listRowSeparator(.hidden)
                            .onTapGesture { router.push(.jobDetail(job.id)) }
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Saved jobs")
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.savedJobs.list()) }
        catch { state = .failed(mortMessage(error)) }
    }

    private func remove(_ id: UUID) async {
        do { try await container.savedJobs.remove(jobID: id); await load() }
        catch { state = .failed(mortMessage(error)) }
    }
}
