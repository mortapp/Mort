//
//  ReportsDisputesView.swift
//  MORT
//
//  Adult/Business view of reports/disputes they're involved in.
//

import SwiftUI

struct ReportsDisputesView: View {
    @Environment(\.services) private var services
    @State private var reports: [Report] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: MortSpacing.sm) {
                if loading {
                    MortLoadingView()
                } else if reports.isEmpty {
                    MortEmptyState(systemImage: "checkmark.shield", title: "No open disputes", message: "Reports and disputes you're involved in will appear here.")
                } else {
                    ForEach(reports) { ReportRow(report: $0) }
                }
            }
            .padding(MortSpacing.md)
        }
        .mortScreen()
        .navigationTitle("Reports & disputes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        loading = true
        reports = (try? await services.reports.fetchAll()) ?? []
        loading = false
    }
}

struct ReportRow: View {
    let report: Report
    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.xs) {
                HStack {
                    MortBadge(text: report.targetType.label, color: MortColor.silver)
                    Spacer()
                    MortBadge.forReport(report.status)
                }
                Text(report.targetLabel).font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                Text(report.reason).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText).lineLimit(2)
                Text("Reported by \(report.reporterName) · ").font(MortFont.caption()).foregroundStyle(MortColor.darkSilver)
                + Text(report.createdAt, style: .relative).font(MortFont.caption()).foregroundStyle(MortColor.darkSilver)
            }
        }
    }
}
