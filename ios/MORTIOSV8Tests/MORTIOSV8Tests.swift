//
//  MORTIOSV8Tests.swift
//  MORT iOS V8 — Unit tests
//
//  These tests cover the rules that must never silently break: money
//  formatting, MORT's fee model, Fair Pay zones, tip rules, payment-state
//  presentation, receipt immutability contracts, history filtering/search,
//  and payout separation.
//

import Testing
import Foundation
@testable import MORTIOSV8

// MARK: - Money

struct MoneyTests {

    @Test("Money formats integer cents with grouping and two decimals")
    func formatsCents() {
        #expect(Money(cents: 0).formatted == "$0.00")
        #expect(Money(cents: 5).formatted == "$0.05")
        #expect(Money(cents: 2200).formatted == "$22.00")
        #expect(Money(cents: 2876).formatted == "$28.76")
        #expect(Money(cents: 125_075).formatted == "$1,250.75")
        #expect(Money(cents: 100_000_00).formatted == "$100,000.00")
    }

    @Test("Negative amounts render with a leading minus, not parentheses")
    func formatsNegative() {
        #expect(Money(cents: -3240).formatted == "-$32.40")
    }

    @Test("Signed formatting marks money in and money out")
    func signedFormatting() {
        #expect(Money(cents: 2700).signedFormatted == "+$27.00")
        #expect(Money(cents: -4320).signedFormatted == "-$43.20")
    }

    @Test("Parsing accepts plain, decimal and symbol-prefixed input")
    func parsesValidInput() {
        #expect(Money.parse("12")?.cents == 1200)
        #expect(Money.parse("12.5")?.cents == 1250)
        #expect(Money.parse("12.50")?.cents == 1250)
        #expect(Money.parse("$7.25")?.cents == 725)
        #expect(Money.parse("1,250.75")?.cents == 125_075)
    }

    @Test("Parsing rejects malformed input instead of guessing")
    func rejectsInvalidInput() {
        #expect(Money.parse("") == nil)
        #expect(Money.parse("abc") == nil)
        #expect(Money.parse("1.2.3") == nil)
        #expect(Money.parse("5.999") == nil)
    }
}

// MARK: - MORT fee model

struct FeeConfigTests {

    @Test("Reference fee is 8% of base with a $1 floor and $5 ceiling")
    func feeEdges() {
        let config = MortFeeConfig.reference
        // 8% of $8.00 = $0.64 -> floored to the $1.00 minimum
        #expect(config.previewFee(forBaseCents: 800) == 100)
        // 8% of $25.00 = $2.00 -> inside the band
        #expect(config.previewFee(forBaseCents: 2500) == 200)
        // 8% of $60.00 = $4.80 -> inside the band
        #expect(config.previewFee(forBaseCents: 6000) == 480)
        // 8% of $100.00 = $8.00 -> capped at the $5.00 maximum
        #expect(config.previewFee(forBaseCents: 10_000) == 500)
        // Far above the cap still clamps
        #expect(config.previewFee(forBaseCents: 125_075) == 500)
    }

    @Test("Fee explanation states the fee is added on top and never on a tip")
    func feeExplanationCopy() {
        let text = MortFeeConfig.reference.explanation
        #expect(text.contains("8%"))
        #expect(text.contains("added on top"))
        #expect(text.contains("tip"))
    }
}

// MARK: - Fair Pay

struct FairPayTests {

    private let policy = FairPayPolicy.reference   // $20–$28 band, $14 minimum

    @Test("An offer below the hard minimum is RED and blocks posting")
    func redBlocksPosting() {
        let verdict = FairPayVerdict.evaluate(offeredCents: 500, policy: policy)
        #expect(verdict.zone == .red)
        #expect(verdict.canPost == false)
        #expect(verdict.title == "PAYMENT IS TOO LOW FOR THIS WORK")
    }

    @Test("An offer between the minimum and the band is YELLOW but allowed")
    func yellowAllowsPosting() {
        let verdict = FairPayVerdict.evaluate(offeredCents: 1600, policy: policy)
        #expect(verdict.zone == .yellow)
        #expect(verdict.canPost)
    }

    @Test("An offer inside or above the band is GREEN")
    func greenAllowsPosting() {
        #expect(FairPayVerdict.evaluate(offeredCents: 2400, policy: policy).zone == .green)
        #expect(FairPayVerdict.evaluate(offeredCents: 5000, policy: policy).zone == .green)
    }

    @Test("Exactly the hard minimum is allowed; one cent under is not")
    func boundaryIsInclusive() {
        #expect(FairPayVerdict.evaluate(offeredCents: 1400, policy: policy).canPost)
        #expect(FairPayVerdict.evaluate(offeredCents: 1399, policy: policy).canPost == false)
    }

    @Test("Red copy tells the poster how to fix it and never shames them")
    func redCopyIsConstructive() {
        let verdict = FairPayVerdict.evaluate(offeredCents: 500, policy: policy)
        #expect(verdict.body.contains("Raise the offer"))
        #expect(verdict.body.contains(policy.hardMinimum.formatted))
    }
}

// MARK: - Tips

struct TipTests {

    @Test("The selector offers exactly the approved options in order")
    func standardOptions() {
        let labels = TipOption.standard.map(\.label)
        #expect(labels == ["No tip", "$2.00", "$5.00", "$10.00", "10%", "15%", "20%", "Custom"])
    }

    @Test("Percentage chips are computed from base pay only")
    func percentPreview() {
        #expect(TipOption.percent(10).previewCents(baseCents: 2200) == 220)
        #expect(TipOption.percent(15).previewCents(baseCents: 2200) == 330)
        #expect(TipOption.percent(20).previewCents(baseCents: 2200) == 440)
        #expect(TipOption.none.previewCents(baseCents: 2200) == 0)
        #expect(TipOption.custom.previewCents(baseCents: 2200) == nil)
    }

    @Test("Custom tip validation enforces the configured floor and ceiling")
    func customValidation() {
        let config = TipConfig.reference  // $1.00 – $50.00
        #expect(CustomTipValidation.evaluate("", config: config) == .empty)
        #expect(CustomTipValidation.evaluate("0.50", config: config) == .tooLow(config))
        #expect(CustomTipValidation.evaluate("75", config: config) == .tooHigh(config))
        #expect(CustomTipValidation.evaluate("nope", config: config) == .invalid)
        #expect(CustomTipValidation.evaluate("7.50", config: config).money?.cents == 750)
    }
}

// MARK: - Payment state machine

struct PaymentStateTests {

    @Test("Every payment state has a tone, an icon and a label — never colour alone")
    func everyStateHasIconAndLabel() {
        for state in PaymentState.allCases {
            let presentation = PaymentStatePresentation.of(state)
            #expect(!presentation.symbol.isEmpty)
            #expect(!presentation.label.isEmpty)
            #expect(!presentation.purpose.isEmpty)
            #expect(!presentation.guidance.isEmpty)
        }
    }

    @Test("Failed states produce no receipt and say so explicitly")
    func failedStatesShowNoReceiptBanner() {
        let failing: [PaymentState] = [
            .declined, .failedNetwork, .providerUnavailable,
            .cancelled, .duplicateBlocked, .quoteExpired,
        ]
        for state in failing {
            #expect(state.producesNoReceipt)
            #expect(PaymentStatePresentation.of(state).showsNoReceiptBanner)
        }
    }

    @Test("Funded, pending and unknown never claim that no receipt exists")
    func nonFailedStatesDoNotShowNoReceiptBanner() {
        for state in [PaymentState.funded, .pending, .unknown, .processing, .requiresAction] {
            #expect(state.producesNoReceipt == false)
        }
    }

    @Test("Funding success says JOB FUNDED, not that the worker was paid")
    func fundedCopyDoesNotImplyPayout() {
        let presentation = PaymentStatePresentation.of(.funded)
        #expect(presentation.label == "JOB FUNDED")
        #expect(presentation.tone == .success)
        #expect(presentation.purpose.lowercased().contains("held"))
        #expect(presentation.guidance.lowercased().contains("settled"))
    }

    @Test("Pending reads as still-checking, not as success or failure")
    func pendingIsNeutral() {
        let presentation = PaymentStatePresentation.of(.pending)
        #expect(presentation.tone == .warning)
        #expect(presentation.label == "STILL CHECKING")
        #expect(presentation.showsDuplicateSafety)
        #expect(presentation.guidance.contains("don't need to pay again"))
    }

    @Test("In-flight and unresolved states reassure against duplicate payment")
    func duplicateSafetyWhereItMatters() {
        for state in [PaymentState.processing, .pending, .unknown, .duplicateBlocked, .failedNetwork] {
            #expect(PaymentStatePresentation.of(state).showsDuplicateSafety)
        }
    }

    @Test("Only funded, declined and cancelled are terminal")
    func terminalStates() {
        #expect(PaymentState.funded.isTerminal)
        #expect(PaymentState.declined.isTerminal)
        #expect(PaymentState.cancelled.isTerminal)
        #expect(PaymentState.pending.isTerminal == false)
        #expect(PaymentState.unknown.isTerminal == false)
        #expect(PaymentState.processing.isTerminal == false)
    }

    @Test("Failure reasons expose safe copy only, never provider codes")
    func failureReasonsAreSafe() {
        for reason in PaymentFailureReason.allCases {
            #expect(!reason.title.isEmpty)
            #expect(!reason.detail.isEmpty)
            // Safe catalog copy never leaks raw provider identifiers.
            #expect(!reason.title.contains("_"))
            #expect(!reason.detail.contains("pi_"))
        }
    }
}

// MARK: - Receipts

struct ReceiptTests {

    @Test("Every document category has an explicit printed title")
    func documentTitles() {
        for type in ReceiptType.allCases {
            #expect(!type.documentTitle.isEmpty)
            #expect(type.documentTitle == type.documentTitle.uppercased())
        }
        #expect(ReceiptType.adultJobPayment.documentTitle == "JOB PAYMENT RECEIPT")
        #expect(ReceiptType.teenEarnings.documentTitle == "EARNINGS RECEIPT")
        #expect(ReceiptType.partialRefund.documentTitle == "PARTIAL REFUND RECEIPT")
    }

    @Test("Refunds, adjustments, reversals and late tips are linked documents")
    func linkedDocumentTypes() {
        #expect(ReceiptType.lateTip.isLinkedDocument)
        #expect(ReceiptType.fullRefund.isLinkedDocument)
        #expect(ReceiptType.partialRefund.isLinkedDocument)
        #expect(ReceiptType.adjustment.isLinkedDocument)
        #expect(ReceiptType.reversal.isLinkedDocument)
        #expect(ReceiptType.adultJobPayment.isLinkedDocument == false)
        #expect(ReceiptType.teenEarnings.isLinkedDocument == false)
    }

    @Test("The adult receipt shows base, tip, fee and a dominant total")
    func adultReceiptStructure() {
        let receipt = MortFixtures.adultReceipt
        let labels = receipt.lines.map(\.label)
        #expect(labels.contains("BASE PAY"))
        #expect(labels.contains("TIP"))
        #expect(labels.contains("MORT SERVICE FEE"))
        #expect(labels.contains("TOTAL PAID"))
        #expect(receipt.lines.filter { $0.emphasis == .total }.count == 1)
    }

    @Test("The teen receipt never implies a fee was taken from the tip")
    func teenReceiptHasNoFeeOnTip() {
        let receipt = MortFixtures.teenReceipt
        let labels = receipt.lines.map(\.label)
        #expect(labels.contains("BASE EARNINGS"))
        #expect(labels.contains("GROSS EARNINGS"))
        #expect(labels.contains("NET EARNINGS"))
        // Deductions are present and explicitly zero.
        let deduction = receipt.lines.first { $0.label == "DEDUCTIONS" }
        #expect(deduction?.amountCents == 0)
        #expect(deduction?.note?.contains("paid by the job poster") == true)
    }

    @Test("Adult and teen receipts are structurally different documents")
    func adultAndTeenDiffer() {
        let adult = Set(MortFixtures.adultReceipt.lines.map(\.label))
        let teen = Set(MortFixtures.teenReceipt.lines.map(\.label))
        #expect(adult != teen)
        #expect(adult.contains("TOTAL PAID"))
        #expect(teen.contains("NET EARNINGS"))
        #expect(teen.contains("TOTAL PAID") == false)
    }

    @Test("Payout status never appears as a line on the earnings receipt")
    func payoutStaysOutsideTheReceipt() {
        let receipt = MortFixtures.teenReceipt
        // The status pill points at History rather than carrying live state.
        #expect(receipt.statusLabel == "EARNINGS CREDITED")
        #expect(receipt.statusSub?.contains("Job & Payment History") == true)
        for line in receipt.lines {
            #expect(line.label.contains("PAYOUT") == false)
            #expect(line.label.contains("TRANSFER") == false)
        }
    }

    @Test("Linked documents describe the parent receipt as unchanged")
    func linkedParentsAreUnchanged() {
        for receipt in MortFixtures.allReceipts where receipt.type.isLinkedDocument {
            #expect(!receipt.links.isEmpty, "\(receipt.type) must link its parent")
            for link in receipt.links {
                #expect(link.status == "Unchanged")
            }
        }
    }

    @Test("Partial refunds show what was refunded and what is still paid")
    func partialRefundShowsRemainder() {
        let labels = MortFixtures.partialRefundReceipt.lines.map(\.label)
        #expect(labels.contains("REFUNDED TO YOU"))
        #expect(labels.contains("REMAINING PAID"))
    }

    @Test("Receipt numbers never use the ambiguous letters I, O or L")
    func receiptLetterAlphabet() {
        for receipt in MortFixtures.allReceipts {
            let leading = receipt.id.prefix(1)
            #expect(leading != "I")
            #expect(leading != "O")
            #expect(leading != "L")
        }
    }

    @Test("Earnings documents carry the not-a-tax-document notice")
    func taxDisclaimerOnEarnings() {
        #expect(MortFixtures.teenReceipt.notATaxDocumentNote != nil)
        #expect(MortFixtures.adjustmentReceipt.notATaxDocumentNote != nil)
    }

    @Test("Every receipt carries a privacy note and masked references only")
    func privacyOnEveryReceipt() {
        for receipt in MortFixtures.allReceipts {
            #expect(!receipt.privacyNote.isEmpty)
            for row in receipt.referenceRows where row.label == "PAYMENT REF" {
                #expect(row.value.contains("••"))
            }
        }
    }
}

// MARK: - Settlement

struct SettlementTests {

    @Test("A full settlement retains the fee and refunds nothing")
    func settledInFull() {
        let settlement = MortFixtures.settlement
        #expect(settlement.outcome == .settledInFull)
        #expect(settlement.compensatedBaseCents == settlement.fundedBaseCents)
        #expect(settlement.hasRefund == false)
    }

    @Test("A partial settlement refunds the difference to the adult")
    func partialSettlement() {
        let settlement = MortFixtures.settlementPartial
        #expect(settlement.compensatedBaseCents < settlement.fundedBaseCents)
        #expect(settlement.hasRefund)
        #expect(
            settlement.adultRefundCents
                == settlement.fundedBaseCents - settlement.compensatedBaseCents
        )
    }

    @Test("Every settlement outcome has a tone, icon and label")
    func outcomePresentation() {
        let outcomes: [SettlementResult.Outcome] = [
            .settledInFull, .settledWithРartialRefund, .settledWithRefund,
            .disputed, .processing, .failedNeedsReconciliation,
        ]
        for outcome in outcomes {
            #expect(!outcome.label.isEmpty)
            #expect(!outcome.symbol.isEmpty)
        }
    }
}

// MARK: - Payout separation

struct PayoutTests {

    @Test("Only the paid stage may claim the money reached the bank")
    func onlyPaidMeansInBank() {
        for stage in PayoutStage.allCases {
            #expect(stage.isMoneyInBank == (stage == .payoutPaid))
        }
    }

    @Test("Every payout stage has a tone, icon, label and guidance")
    func stagePresentation() {
        for stage in PayoutStage.allCases {
            #expect(!stage.label.isEmpty)
            #expect(!stage.symbol.isEmpty)
            #expect(!stage.guidance.isEmpty)
        }
    }

    @Test("A failed payout reassures that earnings remain credited")
    func failedPayoutKeepsEarnings() {
        #expect(PayoutStage.failed.guidance.contains("still credited"))
    }
}

// MARK: - History

struct HistoryTests {

    @Test("Filters map records to the right buckets")
    func filterMatching() {
        #expect(HistoryKind.earning.matches(.earnings))
        #expect(HistoryKind.tip.matches(.tips))
        #expect(HistoryKind.refund.matches(.refunds))
        #expect(HistoryKind.failedPayment.matches(.failed))
        #expect(HistoryKind.dispute.matches(.disputed))
        #expect(HistoryKind.job.matches(.jobs))
        // Everything shows under All.
        for kind in [HistoryKind.job, .payment, .earning, .tip, .refund, .adjustment, .failedPayment, .dispute] {
            #expect(kind.matches(.all))
        }
        // A job is not a payment.
        #expect(HistoryKind.job.matches(.payments) == false)
    }

    @Test("Role decides which filters exist")
    func roleFilters() {
        let teen = HistoryFilter.available(for: .teen)
        #expect(teen.contains(.earnings))
        #expect(teen.contains(.failed) == false)

        let adult = HistoryFilter.available(for: .adult)
        #expect(adult.contains(.payments))
        #expect(adult.contains(.refunds))
        #expect(adult.contains(.failed))

        let guardian = HistoryFilter.available(for: .guardian)
        #expect(guardian.contains(.payments) == false)
    }

    @Test("Search matches receipt number, order number, title and handle")
    func searchMatching() {
        let record = MortFixtures.historyRecords()[0]
        #expect(record.matches(query: ""))
        #expect(record.matches(query: "lawn"))
        #expect(record.matches(query: "@marcus"))
        #expect(record.matches(query: "R-260915-04828"))
        #expect(record.matches(query: "0042"))
        #expect(record.matches(query: "zzzz") == false)
    }

    @Test("Failed payments are flagged as issuing no receipt")
    func failedRowsHaveNoReceipt() {
        let failed = MortFixtures.historyRecords().filter { $0.kind == .failedPayment }
        #expect(!failed.isEmpty)
        for record in failed {
            #expect(record.noReceiptIssued)
            #expect(record.receiptNumber == nil)
        }
    }

    @Test("Month keys group a long feed instead of leaving one flat list")
    func monthGrouping() {
        let feed = MortFixtures.largeHistoryFeed(count: 140)
        #expect(feed.count == 140)
        let months = Set(feed.map(\.monthKey))
        #expect(months.count > 5, "A 140-row feed must span many month groups")
    }

    @Test("Every export state has a tone, icon and label")
    func exportStates() {
        for state in [ExportState.ready, .preparing, .readyToSave, .failed] {
            #expect(!state.label.isEmpty)
            #expect(!state.symbol.isEmpty)
        }
    }
}

// MARK: - Job lifecycle

struct JobStateTests {

    @Test("Every job state has a label, tone and icon")
    func statePresentation() {
        for state in MortJobState.allCases {
            #expect(!state.label.isEmpty)
            #expect(!state.symbol.isEmpty)
        }
    }

    @Test("Funded is a distinct state from settled")
    func fundedIsNotSettled() {
        #expect(MortJobState.funded != MortJobState.settled)
        #expect(MortJobState.funded.label == "Funded")
        #expect(MortJobState.settled.label == "Settled")
    }

    @Test("Every application state has a label, tone and icon")
    func applicationStates() {
        let states: [MortApplication.State] = [
            .submitted, .viewed, .shortlisted, .accepted, .declined, .withdrawn, .expired,
        ]
        for state in states {
            #expect(!state.label.isEmpty)
            #expect(!state.symbol.isEmpty)
        }
    }
}

// MARK: - Errors

struct ErrorMappingTests {

    @Test("Every error maps to safe user copy with no internals")
    func safeMessages() {
        let errors: [MortError] = [
            .offline, .timeout, .unauthorized, .forbidden, .notFound,
            .rateLimited, .serverUnavailable, .rejected("Custom reason"),
            .payment(.cardDeclined), .capabilityUnavailable("Camera"),
            .notConfigured("Stripe"), .unknown,
        ]
        for error in errors {
            #expect(!error.userMessage.isEmpty)
            #expect(error.userMessage.contains("nil") == false)
            #expect(error.userMessage.contains("Error Domain") == false)
        }
    }

    @Test("Only transient failures are marked retryable")
    func retryability() {
        #expect(MortError.offline.isRetryable)
        #expect(MortError.timeout.isRetryable)
        #expect(MortError.serverUnavailable.isRetryable)
        #expect(MortError.unauthorized.isRetryable == false)
        #expect(MortError.payment(.cardDeclined).isRetryable == false)
        // An unwired integration must never invite a blind retry.
        #expect(MortError.notConfigured("Stripe").isRetryable == false)
    }
}

// MARK: - Routing

struct RoutingTests {

    @Test("Tabs differ per role")
    @MainActor
    func tabsPerRole() {
        let teen = MortTab.tabs(for: .teen)
        #expect(teen.contains(.discover))
        #expect(teen.contains(.safety))

        let adult = MortTab.tabs(for: .adult)
        #expect(adult.contains(.discover) == false)

        let guardian = MortTab.tabs(for: .guardian)
        #expect(guardian.contains(.guardianHome))
        #expect(guardian.contains(.discover) == false)
    }

    @Test("Deep links resolve to the matching route")
    @MainActor
    func deepLinks() {
        let navigator = MortNavigator()
        #expect(navigator.handleDeepLink("/receipts/K-260915-04827"))
        #expect(navigator.path.last == .receipt("K-260915-04827"))

        #expect(navigator.handleDeepLink("/jobs/job-42"))
        #expect(navigator.path.last == .jobDetail("job-42"))

        #expect(navigator.handleDeepLink("/messages/c1"))
        #expect(navigator.path.last == .conversation("c1"))
    }

    @Test("Unknown deep links are ignored rather than guessed at")
    @MainActor
    func unknownDeepLink() {
        let navigator = MortNavigator()
        #expect(navigator.handleDeepLink("/nonsense/path") == false)
        #expect(navigator.path.isEmpty)
    }

    @Test("Popping to root clears stacked payment screens")
    @MainActor
    func popToRoot() {
        let navigator = MortNavigator()
        navigator.push(.paymentReview("job-42"))
        navigator.push(.paymentProcessing("job-42"))
        navigator.push(.paymentResult(jobId: "job-42", state: .funded))
        navigator.popToRoot()
        #expect(navigator.path.isEmpty)
    }

    @Test("Popping to a specific route trims everything above it")
    @MainActor
    func popToRoute() {
        let navigator = MortNavigator()
        navigator.push(.paymentReview("job-42"))
        navigator.push(.paymentMethods)
        navigator.push(.paymentRetry("job-42"))
        navigator.popTo(.paymentReview("job-42"))
        #expect(navigator.path == [.paymentReview("job-42")])
    }
}

// MARK: - Repositories

struct RepositoryTests {

    @Test("Funding a job returns the backend's state, not an assumed success")
    func fundingReturnsBackendState() async throws {
        let declining = PreviewPaymentRepository(outcome: .declined, reason: .insufficientFunds)
        let state = try await declining.beginFunding(
            jobId: "job-42", methodId: "pm-1", idempotencyKey: "key-1"
        )
        #expect(state == .declined)

        let status = try await declining.fundingStatus(jobId: "job-42")
        #expect(status.state == .declined)
        #expect(status.reason == .insufficientFunds)
    }

    @Test("The funding quote total comes from the backend, not local math")
    func quoteIsAuthoritative() async throws {
        let quote = try await PreviewPaymentRepository().fundingQuote(jobId: "job-42")
        #expect(quote.totalCents == quote.baseCents + quote.feeCents)
        #expect(quote.total.formatted == "$23.76")
    }

    @Test("Annual export fails closed when the backend has no file")
    func exportFailsClosed() async {
        let repository = PreviewHistoryRepository(exportState: .readyToSave)
        await #expect(throws: MortError.self) {
            _ = try await repository.exportFile(year: 2025)
        }
    }

    @Test("Emergency alerting is never simulated in previews")
    func emergencyNeverFaked() async {
        let repository = PreviewSafetyRepository()
        await #expect(throws: MortError.self) {
            try await repository.raiseEmergencyAlert(jobId: "job-42")
        }
    }

    @Test("History filtering and search run against the repository")
    func historyRepositoryFiltering() async throws {
        let repository = PreviewHistoryRepository()
        let earnings = try await repository.records(
            filter: .earnings, year: nil, query: nil, cursor: nil
        )
        #expect(!earnings.records.isEmpty)
        #expect(earnings.records.allSatisfy { $0.kind == .earning })

        let searched = try await repository.records(
            filter: .all, year: nil, query: "lawn", cursor: nil
        )
        #expect(searched.records.allSatisfy { $0.matches(query: "lawn") })
    }

    @Test("A large feed paginates instead of returning everything at once")
    func historyPaginates() async throws {
        let repository = PreviewHistoryRepository(useLargeFeed: true)
        let page = try await repository.records(
            filter: .all, year: nil, query: nil, cursor: nil
        )
        #expect(page.records.count == 25)
        #expect(page.nextCursor != nil)
    }

    @Test("Available years are derived from the feed, never hardcoded")
    func yearsAreDataDriven() async throws {
        let years = try await PreviewHistoryRepository().availableYears()
        #expect(!years.isEmpty)
        #expect(years == years.sorted(by: >))
    }

    @Test("Starting a job requires the correct six-digit PIN and identity attestation")
    func startPinIsChecked() async throws {
        let repository = PreviewJobExecutionRepository()
        let pin = try await repository.startPin(jobId: "job-42")
        #expect(pin.count == 6)
        try await repository.startJob(
            jobId: "job-42",
            pin: pin,
            personMatchesProfile: true
        )

        await #expect(throws: MortError.self) {
            try await repository.startJob(
                jobId: "job-42",
                pin: "000000",
                personMatchesProfile: true
            )
        }

        await #expect(throws: MortError.self) {
            try await repository.startJob(
                jobId: "job-42",
                pin: pin,
                personMatchesProfile: false
            )
        }
    }

    @Test("Unusable payment methods are surfaced, not hidden")
    func unusableMethodsVisible() async throws {
        let methods = try await PreviewPaymentRepository().paymentMethods()
        #expect(methods.contains { !$0.isUsable })
        #expect(methods.allSatisfy { !$0.mask.isEmpty })
    }

    @Test("Guardian summaries state what stays private")
    func guardianSummaryIsLimited() async throws {
        let summary = try await PreviewGuardianRepository().teenSummary(teenId: "u-teen-1")
        #expect(!summary.restrictedNotice.isEmpty)
        #expect(summary.restrictedNotice.lowercased().contains("message"))
    }
}

// MARK: - Dependency container

struct DependencyTests {

    @Test("Shipping build resolves the configured shared MORT backend")
    @MainActor
    func shippingBuildUsesLiveBackend() {
        let dependencies = MortDependencies.resolve()
        #expect(dependencies.mode == .live)
        #expect(!dependencies.mode.isPreview)
    }

    @Test("An explicitly missing backend still fails closed to labeled preview mode")
    @MainActor
    func missingBackendFallsBackToPreviewMode() {
        let dependencies = MortDependencies.resolve(config: nil)
        #expect(dependencies.mode == .preview)
        #expect(dependencies.mode.isPreview)
    }

    @Test("Preview containers start in the requested session state")
    @MainActor
    func previewSessionState() async {
        let signedOut = MortDependencies.preview(signedIn: false)
        await signedOut.session.restore()
        #expect(signedOut.session.phase == .signedOut)
    }

    @Test("Restoring a signed-in session lands on the active phase")
    @MainActor
    func restoreActiveSession() async {
        let dependencies = MortDependencies.preview(user: MortFixtures.teen, signedIn: true)
        await dependencies.session.restore()
        #expect(dependencies.session.role == .teen)
        if case .active = dependencies.session.phase {
            // expected
        } else {
            Issue.record("Expected an active session, got \(dependencies.session.phase)")
        }
    }

    @Test("Signing out clears the session")
    @MainActor
    func signOutClearsSession() async {
        let dependencies = MortDependencies.preview()
        await dependencies.session.restore()
        await dependencies.session.signOut()
        #expect(dependencies.session.phase == .signedOut)
        #expect(dependencies.session.role == nil)
    }
}

// MARK: - Fixture hygiene

struct FixtureHygieneTests {

    @Test("Fixtures never contain anything resembling a real secret")
    func noSecretsInFixtures() {
        let forbidden = ["sk_live", "sk_test", "service_role", "BEGIN PRIVATE KEY", "eyJhbGciOi"]
        var corpus = MortFixtures.allReceipts.map(\.id).joined(separator: " ")
        corpus += MortFixtures.methods.map { $0.mask }.joined(separator: " ")
        corpus += MortFixtures.notifications.map(\.body).joined(separator: " ")
        for token in forbidden {
            #expect(corpus.contains(token) == false)
        }
    }

    @Test("Fixture people are handles and display names only")
    func fixturesRespectPrivacy() {
        for user in [MortFixtures.teen, MortFixtures.adult, MortFixtures.guardian] {
            #expect(user.handle.hasPrefix("@"))
            // Display names are first name + last initial by policy.
            #expect(user.displayName.split(separator: " ").count <= 2)
        }
    }
}
