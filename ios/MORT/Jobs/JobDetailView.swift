//
//  JobDetailView.swift
//  MORT
//

import SwiftUI

struct JobDetailView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    let job: Job
    @State private var showApply = false
    @State private var showReport = false
    @State private var applied = false

    private var isTeen: Bool { session.currentRole == .teen }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.md) {
                HStack(spacing: MortSpacing.sm) {
                    Image(systemName: job.category.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MortColor.roseGold)
                        .frame(width: 52, height: 52)
                        .background(MortColor.roseGold.opacity(0.14))
                        .clipShape(.rect(cornerRadius: MortRadius.sm))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(job.title).font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
                        Text(job.category.label).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                    }
                    Spacer()
                    MortBadge.forStatus(job.status)
                }

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        InfoRow(icon: "person.fill", label: "Posted by", value: job.posterName)
                        InfoRow(icon: "mappin.and.ellipse", label: "Location", value: job.locationLabel)
                        InfoRow(icon: "dollarsign.circle", label: "Estimated pay", value: job.estimatedPayText)
                        if let date = job.scheduledAt {
                            InfoRow(icon: "calendar", label: "When", value: date.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }

                Section(title: "Description", text: job.description)
                if !job.requirements.isEmpty { Section(title: "Requirements", text: job.requirements) }

                MortSafetyBanner(staticMessage: job.safetyNotes.isEmpty ? "Meet in safe, public, daytime settings. Keep all chat inside MORT." : job.safetyNotes)

                MortSafetyBanner(result: SafetyScanResult(severity: .safe, matches: [], message: "Estimated pay is shown for reference only. MORT never processes payments."))

                if isTeen {
                    if applied {
                        MortButton(title: "Application sent", systemImage: "checkmark", kind: .secondary, isDisabled: true) {}
                    } else {
                        MortButton(title: "Apply for this job", systemImage: "paperplane.fill") { showApply = true }
                    }
                }

                MortButton(title: "Report this job", systemImage: "flag.fill", kind: .ghost) { showReport = true }
            }
            .padding(MortSpacing.md)
            .padding(.bottom, MortSpacing.xl)
        }
        .mortScreen()
        .navigationTitle("Job details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showApply) {
            ApplyJobView(job: job) { applied = true }
        }
        .sheet(isPresented: $showReport) {
            if let me = session.profile {
                ReportSheet(targetType: .job, targetId: job.id, targetLabel: job.title, reporter: me)
            }
        }
    }
}

private struct Section: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            Text(title.uppercased()).font(MortFont.tiny()).tracking(0.8).foregroundStyle(MortColor.darkSilver)
            Text(text).font(MortFont.body()).foregroundStyle(MortColor.silver)
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: MortSpacing.sm) {
            Image(systemName: icon).foregroundStyle(MortColor.roseGold).frame(width: 22)
            Text(label).font(MortFont.callout()).foregroundStyle(MortColor.secondaryText)
            Spacer()
            Text(value).font(MortFont.callout()).foregroundStyle(MortColor.primaryText)
        }
    }
}

struct ApplyJobView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let job: Job
    var onApplied: () -> Void

    @State private var message = ""
    @State private var scan: SafetyScanResult = .safe
    @State private var submitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    Text("Apply for ‘\(job.title)’")
                        .font(MortFont.title2()).foregroundStyle(MortColor.primaryText)

                    MortTextField(title: "Message to poster", text: $message, placeholder: "Introduce yourself and your availability…", autocapitalization: .sentences)
                        .onChange(of: message) { _, newValue in scan = SafetyScanner.scan(newValue) }

                    if !scan.isSafe {
                        MortSafetyBanner(result: scan)
                    }

                    MortButton(title: "Send application", isLoading: submitting, isDisabled: message.trimmingCharacters(in: .whitespaces).isEmpty || scan.isBlocked) {
                        Task { await submit() }
                    }
                }
                .padding(MortSpacing.md)
            }
            .background(MortColor.background.ignoresSafeArea())
            .navigationTitle("Apply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(MortColor.roseGold)
                }
            }
        }
    }

    private func submit() async {
        guard let me = session.profile else { return }
        submitting = true
        _ = try? await services.jobs.apply(to: job, applicant: me, message: message)
        submitting = false
        onApplied()
        dismiss()
    }
}
