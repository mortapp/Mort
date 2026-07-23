import SwiftUI

struct AdultDashboardView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var jobs: LoadState<[Job]> = .idle
    @State private var applications: LoadState<[MortApplication]> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                dashboardHeader
                HStack(spacing: MortSpacing.sm) {
                    metric("Jobs", value: count(jobs), tint: MortColors.neon)
                    metric("Applicants", value: count(applications), tint: MortColors.safetyBlue)
                }
                MortPrimaryButton(title: "Post a job", icon: "plus") { router.push(.jobWizard(nil)) }
                MortSectionHeader(title: "Adult and business tools")
                DashboardLink(title: "Manage jobs", subtitle: "Pause, resume, close, cancel, or duplicate", icon: "briefcase.fill", route: .myJobs)
                DashboardLink(title: "Review applicants", subtitle: "Backend-authorized status actions and timelines", icon: "person.2.fill", route: .applications(.adult))
                DashboardLink(title: "Business verification", subtitle: "Submit documents to private storage", icon: "checkmark.shield.fill", route: .verification)
                DashboardLink(title: "Messages", subtitle: "Safety-scanned in-app conversations", icon: "bubble.left.and.bubble.right.fill", route: .messages)
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("MORT")
        .toolbar { notificationToolbar }
        .refreshable { await load() }
        .task { await load() }
        .mortScreen()
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            Text("POST. REVIEW. GET IT DONE.").font(MortTypography.caption).foregroundStyle(MortColors.neon)
            Text("Your local work desk").font(MortTypography.title)
            Text("Verification, moderation, and application rules remain enforced by Supabase.")
                .foregroundStyle(MortColors.textMuted)
        }
    }

    @ToolbarContentBuilder
    private var notificationToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { router.push(.notifications) } label: { Image(systemName: "bell") }
            .accessibilityLabel("Notifications")
        }
    }

    private func load() async {
        jobs = .loading
        applications = .loading
        do { jobs = .loaded(try await container.jobs.listMine()) }
        catch { jobs = .failed(mortMessage(error)) }
        do { applications = .loaded(try await container.applications.listForMyJobs()) }
        catch { applications = .failed(mortMessage(error)) }
    }
}

struct GuardianDashboardView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var connections: LoadState<[GuardianConnection]> = .idle
    @State private var pings: LoadState<[SafetyPing]> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                Text("Guardian Mode").font(MortTypography.title)
                Text("See only the safety information your linked teen and backend policy allow.")
                    .foregroundStyle(MortColors.textMuted)
                HStack(spacing: MortSpacing.sm) {
                    metric("Linked teens", value: count(connections), tint: MortColors.safetyBlue)
                    metric("Safety pings", value: count(pings), tint: MortColors.warning)
                }
                DashboardLink(title: "Manage connections", subtitle: "Invites, privacy choices, and unlinking", icon: "person.2.badge.gearshape", route: .guardianMode)
                DashboardLink(title: "Safety pings", subtitle: "Authorized check-ins from linked teens", icon: "location.fill", route: .guardianSafetyPings)
                DashboardLink(title: "Job approvals", subtitle: "Shown only when an individual job requires it", icon: "checkmark.seal.fill", route: .applications(.guardian))
                MortSafetyBanner(message: "Guardian Mode does not expose unrestricted private messages and does not replace direct communication or emergency services.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("MORT")
        .refreshable { await load() }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        connections = .loading
        pings = .loading
        do { connections = .loaded(try await container.guardians.connections()) }
        catch { connections = .failed(mortMessage(error)) }
        do { pings = .loaded(try await container.safety.visibleSafetyPings()) }
        catch { pings = .failed(mortMessage(error)) }
    }
}

func count<T>(_ state: LoadState<[T]>) -> String {
    switch state {
    case let .loaded(items): String(items.count)
    case .failed: "!"
    case .idle, .loading: "..."
    }
}

func metric(_ label: String, value: String, tint: Color) -> some View {
    MortCard {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            Text(value).font(MortTypography.title).foregroundStyle(tint)
            Text(label).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
        }
    }
}

private struct DashboardLink: View {
    @Environment(Router.self) private var router
    let title: String
    let subtitle: String
    let icon: String
    let route: AppRoute

    var body: some View {
        Button { router.push(route) } label: {
        MortCard {
            HStack(spacing: MortSpacing.md) {
                Image(systemName: icon).font(.title2).foregroundStyle(MortColors.neon).frame(width: 30)
                VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                    Text(title).font(MortTypography.label).foregroundStyle(MortColors.text)
                    Text(subtitle).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(MortColors.textMuted)
            }
        }
        }
        .buttonStyle(.plain)
    }
}
