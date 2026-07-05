//
//  PostJobView.swift
//  MORT
//
//  Adult/Business job posting with safety scanning before creation.
//

import SwiftUI

struct PostJobView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var onPosted: (() -> Void)? = nil

    @State private var title = ""
    @State private var description = ""
    @State private var category: JobCategory = .yardWork
    @State private var locationLabel = ""
    @State private var pay = ""
    @State private var scheduledAt = Date()
    @State private var requirements = ""
    @State private var safetyNotes = ""

    @State private var scan: SafetyScanResult = .safe
    @State private var scheduleScan: SafetyScanResult = .safe
    @State private var submitting = false

    private var combinedText: String {
        [title, description, locationLabel, requirements, safetyNotes].joined(separator: " \n ")
    }

    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
        && !pay.trimmingCharacters(in: .whitespaces).isEmpty
        && !scan.isBlocked
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    MortTextField(title: "Job title", text: $title, placeholder: "e.g. Rake leaves in backyard", autocapitalization: .sentences)

                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        Text("CATEGORY").font(MortFont.tiny()).tracking(0.8).foregroundStyle(MortColor.darkSilver)
                        Picker("Category", selection: $category) {
                            ForEach(JobCategory.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(MortColor.roseGold)
                        .padding(.horizontal, MortSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mortSurface(cornerRadius: MortRadius.sm)
                    }

                    MortTextField(title: "Description", text: $description, placeholder: "Describe the task and how long it takes…", autocapitalization: .sentences)
                    MortTextField(title: "Location label", text: $locationLabel, placeholder: "e.g. Maple Heights (no street address)", autocapitalization: .words)
                    MortTextField(title: "Estimated pay text", text: $pay, placeholder: "e.g. $25–35", autocapitalization: .never)

                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        Text("DATE & TIME").font(MortFont.tiny()).tracking(0.8).foregroundStyle(MortColor.darkSilver)
                        DatePicker("When", selection: $scheduledAt, in: Date()...)
                            .datePickerStyle(.compact)
                            .tint(MortColor.roseGold)
                            .padding(MortSpacing.sm)
                            .mortSurface(cornerRadius: MortRadius.sm)
                            .onChange(of: scheduledAt) { _, newValue in scheduleScan = SafetyScanner.scanSchedule(newValue) }
                    }

                    MortTextField(title: "Requirements", text: $requirements, placeholder: "Anything the helper should know", autocapitalization: .sentences)
                    MortTextField(title: "Safety notes", text: $safetyNotes, placeholder: "e.g. Daytime only, adult present", autocapitalization: .sentences)

                    if !scan.isSafe { MortSafetyBanner(result: scan) }
                    if !scheduleScan.isSafe { MortSafetyBanner(result: scheduleScan) }

                    MortSafetyBanner(staticMessage: "No real-world payments are processed in MORT. Estimated pay is for reference only.")

                    MortButton(title: "Post job", systemImage: "checkmark.circle.fill", isLoading: submitting, isDisabled: !canPost) {
                        Task { await post() }
                    }
                }
                .padding(MortSpacing.md)
            }
            .background(MortColor.background.ignoresSafeArea())
            .navigationTitle("Post a job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(MortColor.roseGold)
                }
            }
            .onChange(of: combinedText) { _, newValue in scan = SafetyScanner.scan(newValue) }
        }
    }

    private func post() async {
        // Run the safety scanner before creating a job.
        let finalScan = SafetyScanner.scan(combinedText)
        scan = finalScan
        if finalScan.isBlocked { return }

        guard let me = session.profile else { return }
        submitting = true
        let job = Job(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description,
            category: category,
            posterId: me.id,
            posterName: me.displayName,
            locationLabel: locationLabel.isEmpty ? "Nearby" : locationLabel,
            estimatedPayText: pay,
            scheduledAt: scheduledAt,
            requirements: requirements,
            safetyNotes: safetyNotes
        )
        _ = try? await services.jobs.createJob(job)
        submitting = false
        onPosted?()
        dismiss()
    }
}

