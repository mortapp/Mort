//
//  ReportSheet.swift
//  MORT
//
//  Reusable sheet for reporting a user, job, or message.
//

import SwiftUI

struct ReportSheet: View {
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    let targetType: ReportTargetType
    let targetId: String
    let targetLabel: String
    let reporter: UserProfile

    @State private var reason = ""
    @State private var submitting = false
    @State private var done = false

    private let presets = [
        "Sharing contact info",
        "Unsafe or inappropriate",
        "Harassment or threats",
        "Spam or scam",
        "Drugs, alcohol, or weapons",
        "Something else",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    if done {
                        MortEmptyState(systemImage: "checkmark.shield.fill", title: "Report submitted", message: "Thanks for helping keep MORT safe. Our team will review this.")
                    } else {
                        Text("Reporting \(targetType.label.lowercased()): \(targetLabel)")
                            .font(MortFont.callout())
                            .foregroundStyle(MortColor.secondaryText)

                        VStack(spacing: MortSpacing.xs) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    reason = preset
                                } label: {
                                    HStack {
                                        Text(preset).font(MortFont.callout()).foregroundStyle(MortColor.primaryText)
                                        Spacer()
                                        if reason == preset {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(MortColor.roseGold)
                                        }
                                    }
                                    .padding(MortSpacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .mortSurface(cornerRadius: MortRadius.sm)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        MortTextField(title: "Details (optional)", text: $reason, placeholder: "Add any details…", autocapitalization: .sentences)

                        MortButton(title: "Submit report", isLoading: submitting, isDisabled: reason.trimmingCharacters(in: .whitespaces).isEmpty) {
                            Task { await submit() }
                        }
                    }
                }
                .padding(MortSpacing.md)
            }
            .background(MortColor.background.ignoresSafeArea())
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(MortColor.roseGold)
                }
            }
        }
    }

    private func submit() async {
        submitting = true
        let report = Report(
            targetType: targetType,
            targetId: targetId,
            targetLabel: targetLabel,
            reporterId: reporter.id,
            reporterName: reporter.displayName,
            reason: reason
        )
        try? await services.reports.submit(report)
        submitting = false
        withAnimation { done = true }
        try? await Task.sleep(for: .seconds(1.4))
        dismiss()
    }
}
