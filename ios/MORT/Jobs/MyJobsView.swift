//
//  MyJobsView.swift
//  MORT
//
//  Teen view of jobs they've applied to.
//

import SwiftUI

struct MyJobsView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    @State private var applications: [JobApplication] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "My jobs", subtitle: "Applications and accepted work")
                content
            }
            .mortScreen()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView()
        } else if applications.isEmpty {
            MortEmptyState(systemImage: "briefcase", title: "No applications yet", message: "When you apply for safe jobs, they'll show up here.")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(applications) { app in
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpacing.xs) {
                                HStack {
                                    Text(app.jobTitle).font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                                    Spacer()
                                    MortBadge.forApplication(app.status)
                                }
                                if !app.message.isEmpty {
                                    Text(app.message).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText).lineLimit(2)
                                }
                                Text(app.createdAt, style: .relative).font(MortFont.caption()).foregroundStyle(MortColor.darkSilver)
                            }
                        }
                    }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func load() async {
        guard let me = session.profile else { return }
        loading = true
        applications = (try? await services.jobs.applications(forApplicant: me.id)) ?? []
        loading = false
    }
}

