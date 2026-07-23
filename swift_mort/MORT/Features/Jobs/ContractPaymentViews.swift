import SwiftUI

struct JobContractsView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var contracts: [JobContractRecord] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading { MortLoadingState(label: "Loading job agreements") }
            else if let error { MortErrorState(message: error) { Task { await load() } } }
            else if contracts.isEmpty {
                MortEmptyState(
                    title: "No job agreements yet",
                    message: "A versioned job agreement is created by the backend when an application is accepted.",
                    systemImage: "doc.text"
                )
            } else {
                List(contracts) { contract in
                    Button { router.push(.jobContract(contract.id)) } label: {
                        VStack(alignment: .leading, spacing: MortSpacing.xs) {
                            Text("Agreement \(contract.id.uuidString.prefix(8))").foregroundStyle(MortColors.text)
                            HStack {
                                MortBadge(text: contract.status.replacingOccurrences(of: "_", with: " ").capitalized, tint: contract.status == "active" ? MortColors.neon : MortColors.warning)
                                Text(contract.classificationStatus.replacingOccurrences(of: "_", with: " "))
                                    .font(MortTypography.caption)
                                    .foregroundStyle(MortColors.textMuted)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Job agreements")
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do { contracts = try await container.jobContracts.contracts(); error = nil }
        catch { self.error = mortMessage(error) }
    }
}

struct JobContractReviewView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    let contractID: UUID

    @State private var contract: JobContractRecord?
    @State private var versions: [JobContractVersionRecord] = []
    @State private var acceptances: [JobContractAcceptanceRecord] = []
    @State private var affirmative = false
    @State private var confirmation = ""
    @State private var loading = true
    @State private var working = false
    @State private var message: String?

    var body: some View {
        Group {
            if loading { MortLoadingState(label: "Loading exact job agreement") }
            else if let version = versions.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: MortSpacing.lg) {
                        MortAlertBanner(
                            title: "Exact, immutable version",
                            message: "Version \(version.versionNumber) is identified by hash \(version.contentHash). A material change creates a new version and requires both parties.",
                            tint: MortColors.safetyBlue,
                            icon: "doc.badge.gearshape"
                        )
                        agreementSection("Parties", rows: [
                            ("Teen", version.teenPublicIdentifier),
                            ("Adult or business", version.adultPublicIdentifier)
                        ])
                        agreementSection("Work", rows: [
                            ("Agreed scope", version.agreedScope),
                            ("Excluded work", version.excludedWork.isEmpty ? "None listed" : version.excludedWork.joined(separator: ", ")),
                            ("Completion", version.completionRequirements),
                            ("Proof", version.proofRequirements)
                        ])
                        agreementSection("Time and place", rows: [
                            ("Service date", version.serviceDate),
                            ("Location type", version.locationType),
                            ("Exact location", version.exactLocationReleaseState),
                            ("Start window", version.startWindow ?? "Not set"),
                            ("Expected end", version.expectedEndWindow ?? "Not set")
                        ])
                        agreementSection("Payment", rows: [
                            ("Amount", version.amountDisplay),
                            ("Maximum hours", version.maximumApprovedHours.map { String($0) } ?? "Not applicable"),
                            ("Preference", version.paymentPreference),
                            ("Due", version.paymentDueRule),
                            ("Authorized expenses", version.authorizedExpenses.isEmpty ? "None" : version.authorizedExpenses.joined(separator: ", "))
                        ])
                        agreementSection("Safety and changes", rows: [
                            ("People present", version.expectedPeoplePresent),
                            ("Supervision", version.supervision),
                            ("Equipment", version.equipment),
                            ("Hazards", version.hazards),
                            ("Cancellation", version.cancellationTerms),
                            ("Material changes", version.materialChangeProcess),
                            ("Disputes", version.disputeProcess),
                            ("Safety agreement", version.safetyAgreementVersion)
                        ])
                        MortSectionHeader(title: "Party confirmations", subtitle: "Both confirmations must match this exact content hash.")
                        if acceptances.isEmpty {
                            Text("No party has confirmed this version yet.").foregroundStyle(MortColors.textMuted)
                        }
                        ForEach(acceptances) { acceptance in
                            Label("\(acceptance.partyRole.capitalized) confirmed \(acceptance.contentHash.prefix(12))...", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(MortColors.neon)
                        }
                        if version.status == "pending_confirmation" {
                            MortTextField(
                                title: "Confirmation",
                                text: $confirmation,
                                prompt: "I reviewed and confirm this exact job agreement."
                            )
                            Toggle("I affirmatively confirm this exact version", isOn: $affirmative)
                            MortPrimaryButton(title: "Confirm exact agreement", icon: "signature", isLoading: working) {
                                Task { await confirm(version) }
                            }
                            .disabled(!affirmative || confirmation.trimmed.count < 8)
                        }
                        HStack {
                            MortSecondaryButton(title: "Material change", icon: "arrow.triangle.2.circlepath") {
                                router.push(.jobContractChange(contractID))
                            }
                            MortSecondaryButton(title: "Payment status", icon: "dollarsign.circle") {
                                router.push(.paymentStatus(contractID))
                            }
                        }
                        MortAlertBanner(
                            title: "Classification is not decided here",
                            message: "The relationship remains \(contract?.classificationStatus.replacingOccurrences(of: "_", with: " ") ?? "classification unknown"). MORT does not conclusively decide employee, contractor, volunteer, or program status.",
                            tint: MortColors.warning,
                            icon: "scale.3d"
                        )
                    }
                    .padding(MortSpacing.lg)
                }
            } else {
                MortErrorState(message: message ?? "This agreement is unavailable.") { Task { await load() } }
            }
        }
        .navigationTitle("Job agreement")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Job agreement", isPresented: Binding(get: { message != nil && !versions.isEmpty }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func agreementSection(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: title)
            MortCard {
                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                            Text(row.0).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                            Text(row.1)
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            async let allContracts = container.jobContracts.contracts()
            async let allVersions = container.jobContracts.versions(contractID: contractID)
            async let allAcceptances = container.jobContracts.acceptances(contractID: contractID)
            let loadedContracts = try await allContracts
            contract = loadedContracts.first { $0.id == contractID }
            versions = try await allVersions
            acceptances = try await allAcceptances
        } catch { message = mortMessage(error) }
    }

    private func confirm(_ version: JobContractVersionRecord) async {
        working = true
        defer { working = false }
        do {
            _ = try await container.jobContracts.confirm(versionID: version.id, confirmation: confirmation)
            affirmative = false
            confirmation = ""
            message = "Your exact-hash confirmation was recorded. The agreement activates only after both parties confirm."
            await load()
        } catch { message = mortMessage(error) }
    }
}

struct JobContractChangeView: View {
    @Environment(DependencyContainer.self) private var container
    let contractID: UUID
    @State private var changes: [JobContractChangeRecord] = []
    @State private var scope = ""
    @State private var fixedAmount = ""
    @State private var reason = ""
    @State private var confirmRequest = false
    @State private var working = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortAlertBanner(
                    title: "Both parties must agree",
                    message: "No one can silently lower pay, expand scope, extend hours, change location, add hazards or expenses, or change payment timing.",
                    tint: MortColors.warning,
                    icon: "person.2.badge.gearshape"
                )
                MortSectionHeader(title: "Propose a material change", subtitle: "Enter only fields that should change. The server creates a new immutable version only after both exact-hash confirmations.")
                MortTextField(title: "Revised scope", text: $scope, prompt: "Optional")
                MortTextField(title: "Revised fixed total", text: $fixedAmount, prompt: "Optional dollars")
                    .keyboardType(.decimalPad)
                MortTextField(title: "Reason", text: $reason, prompt: "Why is this change needed?", axis: .vertical)
                Toggle("I understand this proposal does not change the agreement by itself", isOn: $confirmRequest)
                MortPrimaryButton(title: "Send change proposal", icon: "paperplane.fill", isLoading: working) {
                    Task { await request() }
                }
                .disabled(!confirmRequest || reason.trimmed.count < 8 || (scope.trimmed.isEmpty && fixedAmount.trimmed.isEmpty))
                MortSectionHeader(title: "Change history")
                if changes.isEmpty { Text("No material changes have been proposed.").foregroundStyle(MortColors.textMuted) }
                ForEach(changes) { change in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            MortBadge(text: change.status.replacingOccurrences(of: "_", with: " ").capitalized, tint: change.status == "accepted" ? MortColors.neon : MortColors.warning)
                            Text(change.changeCategories.joined(separator: ", ")).font(MortTypography.label)
                            Text(change.reason).foregroundStyle(MortColors.textMuted)
                            Text("Proposed hash: \(change.proposedContentHash)").font(MortTypography.caption).textSelection(.enabled)
                            if change.status == "pending_both_parties" {
                                HStack {
                                    MortSecondaryButton(title: "Accept exact proposal", icon: "checkmark") { Task { await respond(change.id, true) } }
                                    MortDangerButton(title: "Decline") { Task { await respond(change.id, false) } }
                                }
                            }
                        }
                    }
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Material changes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Contract change", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func load() async {
        do { changes = try await container.jobContracts.changes(contractID: contractID) }
        catch { message = mortMessage(error) }
    }

    private func request() async {
        var patch: [String: JSONValue] = [:]
        if !scope.trimmed.isEmpty { patch["agreed_scope"] = .string(scope.trimmed) }
        if let dollars = Double(fixedAmount), dollars >= 0 {
            patch["fixed_total_cents"] = .number((dollars * 100).rounded())
            patch["amount_type"] = .string("fixed")
            patch["hourly_rate_cents"] = .null
        }
        guard !patch.isEmpty else { return }
        working = true
        defer { working = false }
        do {
            _ = try await container.jobContracts.requestChange(contractID: contractID, patch: patch, reason: reason)
            scope = ""; fixedAmount = ""; reason = ""; confirmRequest = false
            message = "Change proposed. The active agreement remains unchanged until both parties accept the exact proposal."
            await load()
        } catch { message = mortMessage(error) }
    }

    private func respond(_ id: UUID, _ accept: Bool) async {
        do {
            _ = try await container.jobContracts.respondToChange(id: id, accept: accept)
            message = accept ? "Your exact proposal response was recorded." : "The proposal was declined; the active agreement remains unchanged."
            await load()
        } catch { message = mortMessage(error) }
    }
}

struct PaymentStatusView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    let contractID: UUID
    @State private var obligations: [PaymentObligationRecord] = []
    @State private var disputes: [PaymentDisputeRecord] = []
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortAlertBanner(
                    title: "Payment record, not payment processing",
                    message: "MORT records the agreed obligation and confirmations. It does not process money, hold escrow, or treat 'poster sent' as 'worker received.'",
                    tint: MortColors.warning,
                    icon: "dollarsign.circle"
                )
                ForEach(obligations) { obligation in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            HStack { Text(obligation.amountDisplay).font(MortTypography.section); Spacer(); MortBadge(text: obligation.status.replacingOccurrences(of: "_", with: " ").capitalized, tint: obligation.status == "worker_confirmed_received" ? MortColors.neon : MortColors.warning) }
                            Text("Due: \(obligation.dueRule.replacingOccurrences(of: "_", with: " "))")
                            Text("Preference: \(obligation.paymentPreference)").foregroundStyle(MortColors.textMuted)
                            if ["due", "poster_marked_sent"].contains(obligation.status) {
                                MortSecondaryButton(title: "Report payment not received", icon: "exclamationmark.bubble.fill") {
                                    router.push(.nonpaymentReport(obligation.id))
                                }
                            }
                        }
                    }
                }
                if obligations.isEmpty { Text("No payment obligation is visible for this agreement.").foregroundStyle(MortColors.textMuted) }
                MortSectionHeader(title: "Private disputes")
                ForEach(disputes) { dispute in
                    Button { router.push(.paymentDispute(dispute.id)) } label: {
                        MortCard {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(dispute.status.replacingOccurrences(of: "_", with: " ").capitalized).foregroundStyle(MortColors.text)
                                    Text("Classification: \(dispute.classificationStatus.replacingOccurrences(of: "_", with: " "))").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                }
                                Spacer(); Image(systemName: "chevron.right")
                            }
                        }
                    }.buttonStyle(.plain)
                }
                MortAlertBanner(
                    title: "Legal information only",
                    message: "MORT does not declare guilt, automatically sue, choose legal claims, promise recovery, or provide legal representation. Official remedies depend on facts and local law.",
                    tint: MortColors.safetyBlue,
                    icon: "info.circle.fill"
                )
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Payment status")
        .task { await load() }
        .alert("Payment status", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
        .mortScreen()
    }

    private func load() async {
        do {
            async let obligationRows = container.jobContracts.obligations(contractID: contractID)
            async let disputeRows = container.jobContracts.disputes(contractID: contractID)
            obligations = try await obligationRows
            disputes = try await disputeRows
        } catch { error = mortMessage(error) }
    }
}

struct NonpaymentReportView: View {
    @Environment(DependencyContainer.self) private var container
    let obligationID: UUID
    @State private var statement = ""
    @State private var confirm = false
    @State private var working = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "Report payment not received", subtitle: "This opens a private allegation and evidence-preservation process. It does not decide guilt.")
            MortTextField(title: "What happened?", text: $statement, prompt: "State what was agreed, completed, and not received.", axis: .vertical)
            Toggle("I understand this is a private report, not a court finding or criminal accusation", isOn: $confirm)
            MortPrimaryButton(title: "Open private nonpayment report", icon: "lock.doc.fill", isLoading: working) { Task { await submit() } }
                .disabled(!confirm || statement.trimmed.count < 20)
            MortAlertBanner(
                title: "What happens next",
                message: "The adult can confirm payment or submit a good-faith dispute. MORT may preserve evidence, pause retaliation-prone publication, assign a trained reviewer, apply a bounded private restriction after review, and provide an authorized export.",
                tint: MortColors.safetyBlue,
                icon: "list.number"
            )
            Spacer()
        }
        .padding(MortSpacing.lg)
        .navigationTitle("Nonpayment report")
        .alert("Nonpayment", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func submit() async {
        working = true
        defer { working = false }
        do {
            _ = try await container.jobContracts.reportNonpayment(obligationID: obligationID, statement: statement)
            statement = ""; confirm = false
            message = "Private report opened. No guilt or legal outcome was automatically determined."
        } catch { message = mortMessage(error) }
    }
}

struct PaymentDisputeView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    let disputeID: UUID
    @State private var dispute: PaymentDisputeRecord?
    @State private var timeline: [PaymentDisputeTimelineRecord] = []
    @State private var statement = ""
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                if let dispute {
                    MortAlertBanner(title: "Private payment review", message: "Status: \(dispute.status.replacingOccurrences(of: "_", with: " ")). Guilt determined: no. Classification: \(dispute.classificationStatus.replacingOccurrences(of: "_", with: " ")).", tint: MortColors.warning, icon: "lock.shield")
                    agreementStatement("Worker statement", dispute.workerStatement)
                    if let poster = dispute.posterStatement { agreementStatement("Poster statement", poster) }
                    MortTextField(title: "Your statement", text: $statement, prompt: "Add relevant facts without threats or private identity data.", axis: .vertical)
                    MortPrimaryButton(title: "Submit private statement", icon: "paperplane.fill") { Task { await submit() } }
                        .disabled(statement.trimmed.count < 10)
                    MortSecondaryButton(title: "Create authorized evidence export", icon: "square.and.arrow.up") { router.push(.evidenceExport(disputeID)) }
                    MortSectionHeader(title: "Timeline")
                    ForEach(timeline) { item in TimelineRow(title: item.eventType.replacingOccurrences(of: "_", with: " ").capitalized, detail: item.eventSummary) }
                } else {
                    MortLoadingState(label: "Loading private dispute")
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Payment dispute")
        .task { await load() }
        .alert("Payment dispute", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func agreementStatement(_ title: String, _ text: String) -> some View {
        MortCard { VStack(alignment: .leading, spacing: MortSpacing.xs) { Text(title).font(MortTypography.section); Text(text).foregroundStyle(MortColors.textMuted) } }
    }

    private func load() async {
        do {
            async let record = container.jobContracts.dispute(id: disputeID)
            async let events = container.jobContracts.disputeTimeline(id: disputeID)
            dispute = try await record
            timeline = try await events
        } catch { message = mortMessage(error) }
    }

    private func submit() async {
        do {
            _ = try await container.jobContracts.submitDisputeStatement(disputeID: disputeID, statement: statement)
            statement = ""; message = "Statement saved in the private dispute record."
            await load()
        } catch { message = mortMessage(error) }
    }
}

struct EvidenceExportView: View {
    @Environment(DependencyContainer.self) private var container
    let disputeID: UUID
    @State private var export: [String: JSONValue]?
    @State private var working = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortAlertBanner(
                    title: "Authorized, minimized export",
                    message: "The export excludes raw identity documents, document numbers, face data, residential addresses, precise coordinates, unrelated incidents, other users' private data, and secrets.",
                    tint: MortColors.safetyBlue,
                    icon: "lock.doc"
                )
                SensitiveActionGate(action: .exportAccountData, title: "Authenticate and generate export") {
                    Task { await generate() }
                }
                if working { MortLoadingState(label: "Generating evidence manifest") }
                if let export {
                    Text("Manifest hash").font(MortTypography.section)
                    Text(export["manifest_hash"]?.displayValue ?? "Unavailable").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Text("Export contents").font(MortTypography.section)
                    Text(export["export"]?.displayValue ?? "Unavailable")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    MortAlertBanner(title: "Not legal advice", message: "This record does not file a lawsuit, select a legal claim, promise recovery, or determine whether a court or wage process applies.", tint: MortColors.warning, icon: "info.circle")
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Evidence export")
        .alert("Evidence export", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func generate() async {
        working = true
        defer { working = false }
        do { export = try await container.jobContracts.evidenceExport(disputeID: disputeID) }
        catch { message = mortMessage(error) }
    }
}
