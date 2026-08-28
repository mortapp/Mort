import SwiftUI

private enum JobWizardStep: Int, CaseIterable {
    case basics
    case workDetails
    case schedule
    case location
    case payment
    case safety
    case preview
    case publish

    var title: String {
        switch self {
        case .basics: "Basics"
        case .workDetails: "Work details"
        case .schedule: "Schedule"
        case .location: "Location"
        case .payment: "Payment"
        case .safety: "Safety"
        case .preview: "Preview"
        case .publish: "Publish"
        }
    }
}

struct JobWizardView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var step: JobWizardStep = .basics
    @State private var draft = JobDraft()
    @State private var payDollars = ""
    @State private var durationMinutes = ""
    @State private var skillsText = ""
    @State private var physicalText = ""
    @State private var includeStart = false
    @State private var includeEnd = false
    @State private var includeDeadline = false
    @State private var isWorking = false
    @State private var didLoad = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    let jobID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            stepHeader
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.lg) {
                    content
                    if let successMessage {
                        MortAlertBanner(title: "Saved", message: successMessage, tint: MortColors.neon, icon: "checkmark.circle.fill")
                    }
                }
                .padding(MortSpacing.lg)
            }
            footer
        }
        .navigationTitle(jobID == nil ? "Post a job" : "Edit job")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save draft") { Task { await save(publish: false) } }
                    .disabled(isWorking)
            }
        }
        .task { await loadExisting() }
        .alert("Job not saved", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .mortScreen()
    }

    private var stepHeader: some View {
        VStack(spacing: MortSpacing.xs) {
            HStack {
                Text(step.title).font(MortTypography.label)
                Spacer()
                Text("\(step.rawValue + 1) / 8").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            }
            ProgressView(value: Double(step.rawValue + 1), total: 8).tint(MortColors.neon)
        }
        .padding(.horizontal, MortSpacing.lg)
        .padding(.vertical, MortSpacing.sm)
        .background(MortColors.elevated)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .basics:
            wizardHeader("What needs doing?", "Be clear, specific, and appropriate for ages 13-17.")
            MortTextField(title: "Job title", text: $draft.title, prompt: "Help clean up a backyard")
            MortTextField(title: "Short summary", text: $draft.summary, prompt: "A quick, useful overview", axis: .vertical)
            MortTextField(title: "Full description", text: $draft.description, prompt: "Scope, expected outcome, and anything applicants should know", axis: .vertical)
            Picker("Category", selection: $draft.category) {
                ForEach(["cleaning", "yard work", "pet care", "moving", "events", "tutoring", "tech help", "other"], id: \.self) { Text($0.capitalized).tag($0) }
            }
            .pickerStyle(.menu)
        case .workDetails:
            wizardHeader("Work details", "Set practical expectations before anyone applies.")
            MortTextField(title: "Estimated minutes", text: $durationMinutes, prompt: "90", keyboardType: .numberPad)
            Stepper("Workers needed: \(draft.workersNeeded)", value: $draft.workersNeeded, in: 1...10)
            Picker("Experience", selection: $draft.experienceLevel) {
                Text("Any").tag("any")
                Text("Beginner").tag("beginner")
                Text("Experienced").tag("experienced")
            }
            MortTextField(title: "Skills (comma separated)", text: $skillsText, prompt: "yard care, organization")
            MortTextField(title: "Equipment provided", text: $draft.equipmentProvided, prompt: "Gloves and bags", axis: .vertical)
            MortTextField(title: "Worker should bring", text: $draft.equipmentWorkerBrings, prompt: "Closed-toe shoes", axis: .vertical)
            MortTextField(title: "Physical requirements", text: $physicalText, prompt: "standing, light lifting")
            Toggle("Proof expected after work", isOn: $draft.proofExpected).tint(MortColors.neon)
            MortTextField(title: "Special instructions", text: $draft.specialInstructions, prompt: "Optional details", axis: .vertical)
        case .schedule:
            wizardHeader("Schedule", "Flexible jobs can omit exact times. Scheduled jobs should use realistic windows.")
            Picker("Schedule type", selection: $draft.scheduleType) {
                Text("Flexible").tag("flexible")
                Text("Scheduled").tag("scheduled")
            }
            Toggle("Set start time", isOn: $includeStart).tint(MortColors.neon)
            if includeStart { DatePicker("Starts", selection: dateBinding(\.startsAt), in: Date()...) }
            Toggle("Set end time", isOn: $includeEnd).tint(MortColors.neon)
            if includeEnd { DatePicker("Ends", selection: dateBinding(\.endsAt), in: Date()...) }
            Toggle("Set application deadline", isOn: $includeDeadline).tint(MortColors.neon)
            if includeDeadline { DatePicker("Deadline", selection: dateBinding(\.deadlineAt), in: Date()...) }
            Toggle("Recurring job", isOn: $draft.recurring).tint(MortColors.neon)
            if draft.recurring { MortTextField(title: "Recurrence", text: $draft.recurrenceRule, prompt: "Every Saturday for 4 weeks") }
            Picker("Urgency", selection: $draft.urgency) {
                Text("Normal").tag("normal")
                Text("Soon").tag("soon")
            }
        case .location:
            wizardHeader("General location", "Share enough to judge travel. Exact addresses belong only in an appropriate, accepted-job flow.")
            MortTextField(title: "Approximate location", text: $draft.locationText, prompt: "Near Broad Ripple")
            MortTextField(title: "City", text: $draft.city, prompt: "Indianapolis", textContentType: .addressCity)
            MortTextField(title: "State", text: $draft.state, prompt: "IN", textContentType: .addressState)
            MortTextField(title: "Neighborhood (optional)", text: $draft.neighborhood, prompt: "General neighborhood")
            MortTextField(title: "ZIP code (optional)", text: $draft.zipCode, prompt: "46220", keyboardType: .numberPad, textContentType: .postalCode)
            Picker("Work environment", selection: $draft.workEnvironment) {
                Text("Unspecified").tag("unspecified")
                Text("Outside").tag("outside")
                Text("Inside").tag("inside")
                Text("Remote").tag("remote")
            }
            Picker("Location type", selection: $draft.locationType) {
                Text("Unspecified").tag("unspecified")
                Text("Residential").tag("residential")
                Text("Business").tag("business")
                Text("Public place").tag("public")
                Text("Remote").tag("remote")
            }
            MortSafetyBanner(message: "Do not put gate codes, school details, or a teen's private address in a public job post.")
        case .payment:
            wizardHeader("Payment preference", "MORT displays the agreed preference but does not process or guarantee payment.")
            MortTextField(title: "Amount in dollars", text: $payDollars, prompt: "25.00", keyboardType: .decimalPad)
            Picker("Payment type", selection: $draft.paymentType) {
                Text("Fixed").tag("fixed")
                Text("Hourly").tag("hourly")
                Text("Discuss in MORT").tag("discuss")
            }
            Picker("Method preference", selection: $draft.paymentMethod) {
                Text("Flexible").tag("flexible")
                Text("Cash").tag("cash")
                Text("Digital").tag("digital")
            }
            Picker("Timing", selection: $draft.paymentTiming) {
                Text("After completion").tag("after_completion")
                Text("After approval").tag("after_approval")
                Text("Per hour").tag("per_hour")
            }
            Toggle("Tips allowed", isOn: $draft.tipAllowed).tint(MortColors.neon)
            MortAlertBanner(title: "No escrow", message: "MORT does not hold money, charge deposits, resolve payment disputes, or guarantee payment.", tint: MortColors.warning, icon: "exclamationmark.triangle.fill")
        case .safety:
            wizardHeader("Safety and requirements", "Set only requirements that are legal, relevant, and appropriate for teen workers.")
            Stepper("Minimum age: \(draft.teenMinAge)", value: $draft.teenMinAge, in: 13...17)
            Stepper("Maximum age: \(draft.teenMaxAge)", value: $draft.teenMaxAge, in: draft.teenMinAge...17)
            Toggle("Adult supervision present", isOn: $draft.adultSupervisionPresent).tint(MortColors.neon)
            Picker("Verification requirement", selection: $draft.verificationRequirement) {
                Text("None").tag("none")
                Text("Verified profile").tag("verified")
            }
            Toggle("Require guardian approval for this job", isOn: $draft.requiresGuardianApproval).tint(MortColors.neon)
            Text("Use guardian approval only when this individual job actually needs it. It is not a platform-wide requirement.")
                .font(MortTypography.caption)
                .foregroundStyle(MortColors.textMuted)
            MortTextField(title: "Safety notes", text: $draft.safetyNotes, prompt: "PPE, supervision, hazards, weather, access", axis: .vertical)
        case .preview:
            wizardHeader("Review the post", "This is the information applicants will use to decide whether to apply.")
            preview
        case .publish:
            wizardHeader("Save or publish", "Publishing runs the backend validator, rate limit, moderation checks, verification rules, and RLS.")
            MortSafetyBanner(message: "Review all details. Publishing never bypasses server-side moderation or account restrictions.")
            MortSecondaryButton(title: "Save as draft", icon: "tray.and.arrow.down") { Task { await save(publish: false) } }
            MortPrimaryButton(title: "Publish job", icon: "paperplane.fill", isLoading: isWorking) { Task { await save(publish: true) } }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: MortSpacing.md) {
            JobPreviewCard(draft: draft, payDollars: payDollars)
            MortSectionHeader(title: "Before publishing")
            Label("No exact private address", systemImage: "checkmark.circle.fill")
            Label("No off-platform contact details", systemImage: "checkmark.circle.fill")
            Label("No deposits, fees, or gift cards", systemImage: "checkmark.circle.fill")
            Label("Work is appropriate for ages \(draft.teenMinAge)-\(draft.teenMaxAge)", systemImage: "checkmark.circle.fill")
        }
        .foregroundStyle(MortColors.textSoft)
    }

    private var footer: some View {
        HStack(spacing: MortSpacing.sm) {
            if step != .basics { Button("Back") { step = JobWizardStep(rawValue: step.rawValue - 1) ?? step }.buttonStyle(.bordered) }
            if step != .publish {
                MortPrimaryButton(title: "Continue", icon: "arrow.right", isDisabled: !stepIsValid) {
                    syncTextFields()
                    step = JobWizardStep(rawValue: step.rawValue + 1) ?? step
                }
            }
        }
        .padding(MortSpacing.md)
        .background(MortColors.elevated)
    }

    private var stepIsValid: Bool {
        switch step {
        case .basics: draft.title.trimmed.count >= 5 && draft.summary.trimmed.count >= 10 && draft.description.trimmed.count >= 20
        case .location: !draft.locationText.trimmed.isEmpty && !draft.city.trimmed.isEmpty && MortValidators.stateCode(draft.state) == nil
        case .payment: draft.paymentType == "discuss" || (Double(payDollars) ?? 0) > 0
        case .safety: draft.teenMinAge <= draft.teenMaxAge
        default: true
        }
    }

    private func wizardHeader(_ title: String, _ subtitle: String) -> some View {
        MortSectionHeader(title: title, subtitle: subtitle)
    }

    private func dateBinding(_ keyPath: WritableKeyPath<JobDraft, Date?>) -> Binding<Date> {
        Binding(
            get: { draft[keyPath: keyPath] ?? Date().addingTimeInterval(3_600) },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }

    private func syncTextFields() {
        if let amount = Decimal(string: payDollars) {
            draft.payAmountCents = NSDecimalNumber(decimal: amount * 100).intValue
        } else {
            draft.payAmountCents = nil
        }
        draft.estimatedDurationMinutes = Int(durationMinutes)
        draft.skillsNeeded = commaValues(skillsText)
        draft.physicalRequirements = commaValues(physicalText)
        if !includeStart { draft.startsAt = nil }
        if !includeEnd { draft.endsAt = nil }
        if !includeDeadline { draft.deadlineAt = nil }
    }

    private func commaValues(_ value: String) -> [String] {
        value.split(separator: ",").map { String($0).trimmed.lowercased() }.filter { !$0.isEmpty }.prefix(12).map { $0 }
    }

    private func loadExisting() async {
        guard !didLoad else { return }
        didLoad = true
        guard let jobID else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            guard let job = try await container.jobs.job(id: jobID) else { throw MortError.invalidInput("This job is no longer available.") }
            draft = JobDraft(job: job)
            payDollars = job.payAmountCents.map { String(format: "%.2f", Double($0) / 100) } ?? ""
            durationMinutes = job.estimatedDurationMinutes.map(String.init) ?? ""
            skillsText = job.skillsNeeded.joined(separator: ", ")
            physicalText = job.physicalRequirements.joined(separator: ", ")
            includeStart = job.startsAt != nil
            includeEnd = job.endsAt != nil
            includeDeadline = job.deadlineAt != nil
        } catch { errorMessage = mortMessage(error) }
    }

    private func save(publish: Bool) async {
        syncTextFields()
        isWorking = true
        defer { isWorking = false }
        do {
            let saved = publish ? try await container.jobs.publish(draft) : try await container.jobs.saveDraft(draft)
            draft.id = saved.id
            successMessage = publish ? "Job published and open to eligible applicants." : "Draft saved in Supabase."
            if publish { router.push(.jobManagement(saved.id)) }
        } catch { errorMessage = mortMessage(error) }
    }
}

private struct JobPreviewCard: View {
    let draft: JobDraft
    let payDollars: String

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                MortBadge(text: draft.category, tint: MortColors.safetyBlue)
                Text(draft.title.nilIfBlank ?? "Untitled job").font(MortTypography.title)
                Text(draft.summary.nilIfBlank ?? "No summary yet").foregroundStyle(MortColors.textMuted)
                Label(payDollars.isEmpty ? "Payment not set" : "$\(payDollars)", systemImage: "dollarsign.circle.fill").foregroundStyle(MortColors.neon)
                Label(draft.locationText.nilIfBlank ?? "Location not set", systemImage: "mappin.and.ellipse")
                Label(draft.scheduleType.capitalized, systemImage: "calendar")
                if draft.requiresGuardianApproval {
                    Label("Guardian approval required for this job", systemImage: "person.2.badge.gearshape").foregroundStyle(MortColors.warning)
                }
            }
        }
    }
}

private extension JobDraft {
    init(job: Job) {
        self.init()
        id = job.id
        clientRequestID = UUID()
        title = job.title
        summary = job.summary ?? ""
        description = job.description
        category = job.category
        estimatedDurationMinutes = job.estimatedDurationMinutes
        workersNeeded = job.workersNeeded
        experienceLevel = job.experienceLevel
        skillsNeeded = job.skillsNeeded
        equipmentProvided = job.equipmentProvided ?? ""
        equipmentWorkerBrings = job.equipmentWorkerBrings ?? ""
        physicalRequirements = job.physicalRequirements
        proofExpected = job.proofExpected
        specialInstructions = job.specialInstructions ?? ""
        scheduleType = job.scheduleType
        let formatter = ISO8601DateFormatter()
        startsAt = job.startsAt.flatMap { formatter.date(from: $0) }
        endsAt = job.endsAt.flatMap { formatter.date(from: $0) }
        deadlineAt = job.deadlineAt.flatMap { formatter.date(from: $0) }
        recurring = job.recurring
        recurrenceRule = job.recurrenceRule ?? ""
        timezone = job.timezone
        urgency = job.urgency
        locationText = job.locationText
        city = job.city
        state = job.state
        neighborhood = job.neighborhood ?? ""
        zipCode = job.zipCode ?? ""
        travelRadiusMiles = job.travelRadiusMiles
        workEnvironment = job.workEnvironment
        locationType = job.locationType
        payAmountCents = job.payAmountCents
        paymentType = job.paymentType
        paymentMethod = job.paymentMethod
        paymentTiming = job.paymentTiming
        tipAllowed = job.tipAllowed
        teenMinAge = job.teenMinAge
        teenMaxAge = job.teenMaxAge
        adultSupervisionPresent = job.adultSupervisionPresent
        verificationRequirement = job.verificationRequirement
        requiresGuardianApproval = job.requiresGuardianApproval
        safetyNotes = job.safetyNotes ?? ""
    }
}
