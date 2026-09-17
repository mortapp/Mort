//
//  MortFixtures.swift
//  MORT iOS V8 — Fixtures
//
//  ISOLATED PREVIEW / TEST FIXTURES.
//
//  Everything in this file is synthetic content used ONLY for SwiftUI previews
//  and tests. It must NEVER masquerade as backend success:
//   - No screen falls back to this data when a repository is empty.
//   - Nothing here implies a real job, person, rating, earning or payout.
//   - No production code path reads this type; only previews and tests do.
//
//  When the real MORT backend is wired, the repositories return live data and
//  this file stays confined to Previews/Tests.
//

import Foundation

/// `nonisolated` so previews, tests and nonisolated model code can read these
/// values without hopping to the main actor. Pure data only.
nonisolated enum MortFixtures {
    // MARK: - People

    static let teen = MortUser(
        id: "u-teen-1",
        handle: "@michael",
        displayName: "Michael R.",
        role: .teen,
        area: "Northside",
        avatarInitials: "MR",
        rating: 4.9,
        completedJobs: 27,
        verifications: ["Guardian linked", "ID checked"],
        memberSince: "Mar 2026",
        bio: "Reliable with yard work and pet care. I bring my own tools for most jobs.",
        guardianLinked: true
    )

    static let adult = MortUser(
        id: "u-adult-1",
        handle: "@marcus",
        displayName: "Marcus T.",
        role: .adult,
        area: "Northside",
        avatarInitials: "MT",
        rating: 4.8,
        completedJobs: 14,
        verifications: ["ID checked", "Payment verified"],
        memberSince: "Jan 2026",
        bio: nil,
        guardianLinked: false
    )

    static let guardian = MortUser(
        id: "u-guardian-1",
        handle: "@dana",
        displayName: "Dana K.",
        role: .guardian,
        area: "Northside",
        avatarInitials: "DK",
        rating: nil,
        completedJobs: 0,
        verifications: ["ID checked"],
        memberSince: "Mar 2026",
        bio: nil,
        guardianLinked: true
    )

    // MARK: - Jobs

    static let job = MortJob(
        id: "job-42",
        title: "Lawn mowing and edging",
        category: "Yard work",
        details: "Front and back lawn, plus edging along the driveway and sidewalk. Mower and trimmer are in the garage — I'll show you where everything is. Please bag the clippings and leave them by the side gate.",
        baseCents: 2200,
        distance: "0.6 mi",
        area: "Northside",
        scheduleText: "Saturday, 10:00 AM",
        posterHandle: "@marcus",
        posterDisplayName: "Marcus T.",
        workerHandle: "@michael",
        state: .funded,
        orderNumber: "0042",
        applicantCount: 4,
        postedAgo: "2 days ago",
        requiresProof: true
    )

    /// Deliberately long content — used to stress-test layout, 200% text and
    /// small-phone widths.
    static let jobLongContent = MortJob(
        id: "job-99",
        title: "Full weekend garage reorganization, shelving assembly and haul-away",
        category: "Heavy lifting",
        details: "This is a bigger one. The garage needs to be fully emptied, swept, and reorganized. There are three flat-pack shelving units to assemble, and roughly ten boxes that need to go to the donation center. It will likely take most of Saturday and part of Sunday morning.",
        baseCents: 125_075,
        distance: "12.4 mi",
        area: "Westbrook Heights",
        scheduleText: "Saturday 9:00 AM – Sunday 12:00 PM",
        posterHandle: "@christopher_bartholomew",
        posterDisplayName: "Christopher B.",
        workerHandle: "@michaelangelo_richardson",
        state: .scheduled,
        orderNumber: "10428",
        applicantCount: 12,
        postedAgo: "5 hours ago",
        requiresProof: true
    )

    static let nearbyJobs: [MortJob] = [
        job,
        MortJob(
            id: "job-43", title: "Walk two friendly dogs", category: "Pet care",
            details: "Biscuit and Mo need a 30-minute walk on weekday afternoons. Both are good on leash.",
            baseCents: 1400, distance: "0.4 mi", area: "Northside",
            scheduleText: "Weekdays 4:00 PM", posterHandle: "@priya", posterDisplayName: "Priya S.",
            workerHandle: nil, state: .open, orderNumber: nil, applicantCount: 2,
            postedAgo: "6 hours ago", requiresProof: false
        ),
        MortJob(
            id: "job-44", title: "Set up a laptop and printer", category: "Tech help",
            details: "New laptop needs setup, plus getting the wireless printer connected.",
            baseCents: 2500, distance: "1.1 mi", area: "Eastgate",
            scheduleText: "This week, flexible", posterHandle: "@ellen", posterDisplayName: "Ellen R.",
            workerHandle: nil, state: .open, orderNumber: nil, applicantCount: 0,
            postedAgo: "1 day ago", requiresProof: false
        ),
        MortJob(
            id: "job-45", title: "Yard cleanup before the rain", category: "Yard work",
            details: "Rake leaves in the back yard and move the patio furniture into the shed.",
            baseCents: 1800, distance: "1.3 mi", area: "Northside",
            scheduleText: "Sunday afternoon", posterHandle: "@omar", posterDisplayName: "Omar H.",
            workerHandle: nil, state: .open, orderNumber: nil, applicantCount: 6,
            postedAgo: "3 days ago", requiresProof: false
        ),
        MortJob(
            id: "job-46", title: "Math tutoring, 7th grade", category: "Tutoring",
            details: "Weekly help with pre-algebra homework. Kitchen table, parent home.",
            baseCents: 2000, distance: "1.8 mi", area: "Westbrook",
            scheduleText: "Tuesdays and Thursdays", posterHandle: "@sofia", posterDisplayName: "Sofia L.",
            workerHandle: nil, state: .open, orderNumber: nil, applicantCount: 3,
            postedAgo: "4 days ago", requiresProof: false
        ),
    ]

    static let myJobs: [MortJob] = [
        job,
        MortJob(
            id: "job-30", title: "Water plants while away", category: "Yard work",
            details: "Three visits — front planters and the vegetable beds.",
            baseCents: 1200, distance: "0.5 mi", area: "Northside",
            scheduleText: "Mon, Wed, Fri", posterHandle: "@sofia", posterDisplayName: "Sofia L.",
            workerHandle: "@michael", state: .inProgress, orderNumber: "0038",
            applicantCount: 1, postedAgo: "1 week ago", requiresProof: false
        ),
        MortJob(
            id: "job-31", title: "Move boxes to storage unit", category: "Delivery",
            details: "About ten boxes from the garage to a storage unit two miles away.",
            baseCents: 4000, distance: "0.9 mi", area: "Eastgate",
            scheduleText: "Saturday 10:00 AM", posterHandle: "@grant", posterDisplayName: "Grant P.",
            workerHandle: "@michael", state: .scheduled, orderNumber: "0035",
            applicantCount: 1, postedAgo: "1 week ago", requiresProof: true
        ),
        MortJob(
            id: "job-32", title: "Grocery run for neighbor", category: "Delivery",
            details: "Short list, store is four blocks away.",
            baseCents: 1500, distance: "0.3 mi", area: "Northside",
            scheduleText: "Last week", posterHandle: "@nina", posterDisplayName: "Nina W.",
            workerHandle: "@michael", state: .settled, orderNumber: "0031",
            applicantCount: 1, postedAgo: "2 weeks ago", requiresProof: false
        ),
    ]

    static let applications: [MortApplication] = [
        .init(
            id: "app-1", jobId: "job-42", jobTitle: "Lawn mowing and edging",
            applicantHandle: "@michael", applicantDisplayName: "Michael R.",
            applicantRating: 4.9, applicantCompletedJobs: 27,
            message: "I've done three lawns on your street. I can start at 10 and should be done in about two hours.",
            state: .accepted, submittedAgo: "2 days ago"
        ),
        .init(
            id: "app-2", jobId: "job-42", jobTitle: "Lawn mowing and edging",
            applicantHandle: "@jordan", applicantDisplayName: "Jordan P.",
            applicantRating: 4.7, applicantCompletedJobs: 11,
            message: "Available Saturday morning. I have my own trimmer if you need it.",
            state: .shortlisted, submittedAgo: "2 days ago"
        ),
        .init(
            id: "app-3", jobId: "job-42", jobTitle: "Lawn mowing and edging",
            applicantHandle: "@sam", applicantDisplayName: "Sam D.",
            applicantRating: nil, applicantCompletedJobs: 0,
            message: "This would be my first MORT job but I mow our lawn every week.",
            state: .submitted, submittedAgo: "1 day ago"
        ),
        .init(
            id: "app-4", jobId: "job-42", jobTitle: "Lawn mowing and edging",
            applicantHandle: "@riley", applicantDisplayName: "Riley T.",
            applicantRating: 4.4, applicantCompletedJobs: 5,
            message: "Could do Sunday instead of Saturday if that works.",
            state: .viewed, submittedAgo: "1 day ago"
        ),
    ]

    // MARK: - Payment OS

    static let method = PaymentMethodRef(
        id: "pm-1", label: "Visa", mask: "•••• 4242",
        symbol: "creditcard", isDefault: true, isUsable: true
    )

    static let methods: [PaymentMethodRef] = [
        method,
        .init(id: "pm-2", label: "Apple Pay", mask: "Default card", symbol: "applelogo", isDefault: false, isUsable: true),
        .init(id: "pm-3", label: "Mastercard", mask: "•••• 5100", symbol: "creditcard", isDefault: false, isUsable: true),
        .init(id: "pm-4", label: "Visa", mask: "•••• 0019", symbol: "creditcard.trianglebadge.exclamationmark", isDefault: false, isUsable: false),
    ]

    static let quote = PaymentQuote(
        jobId: "job-42",
        jobTitle: "Lawn mowing and edging",
        workerHandle: "@michael",
        orderNumber: "0042",
        baseCents: 2200,
        feeCents: 176,
        totalCents: 2376,
        feeExplanation: MortFeeConfig.reference.explanation,
        expiresAt: Date().addingTimeInterval(900),
        method: method
    )

    static let settlement = SettlementResult(
        jobId: "job-42",
        orderNumber: "0042",
        fundedBaseCents: 2200,
        compensatedBaseCents: 2200,
        feeRetainedCents: 176,
        feeRefundedCents: 0,
        adultRefundCents: 0,
        outcome: .settledInFull,
        explanation: "The job was confirmed complete at the agreed base pay. Nothing was refunded."
    )

    static let settlementPartial = SettlementResult(
        jobId: "job-99",
        orderNumber: "10428",
        fundedBaseCents: 125_075,
        compensatedBaseCents: 90_000,
        feeRetainedCents: 500,
        feeRefundedCents: 0,
        adultRefundCents: 35_075,
        outcome: .settledWithРartialRefund,
        explanation: "Part of the work wasn't completed, so MORT settled the confirmed portion and refunded the difference to you."
    )

    // MARK: - Receipts

    static let privacyNote = "This receipt shows usernames and masked payment references only. It never includes full names, addresses, or card numbers."

    static let adultReceipt = Receipt(
        id: "K-260915-04827",
        type: .adultJobPayment,
        orderNumber: "0042",
        issuedAt: Date(timeIntervalSince1970: 1_789_000_000),
        identityRows: [
            .init(id: "r1", label: "PAID BY", value: "@marcus"),
            .init(id: "r2", label: "PAID TO", value: "@michael"),
        ],
        serviceTitle: "Lawn mowing and edging",
        serviceLines: ["Yard work · Northside", "Saturday, 10:00 AM", "Confirmed complete by both people"],
        lines: [
            .init(id: "l1", label: "BASE PAY", amountCents: 2200, emphasis: .normal, note: nil),
            .init(id: "l2", label: "TIP", amountCents: 500, emphasis: .normal, note: "100% to @michael"),
            .init(id: "l3", label: "MORT SERVICE FEE", amountCents: 176, emphasis: .normal, note: "8% of base pay · never charged on the tip"),
            .init(id: "l4", label: "TOTAL PAID", amountCents: 2876, emphasis: .total, note: nil),
        ],
        statusTone: .success,
        statusLabel: "PAID",
        statusSub: "Settled and confirmed",
        methodLabel: "Visa",
        methodMask: "•••• 4242",
        referenceRows: [
            .init(id: "ref1", label: "RECEIPT #", value: "K-260915-04827"),
            .init(id: "ref2", label: "ORDER #", value: "0042"),
            .init(id: "ref3", label: "PAYMENT REF", value: "pi_••••_8fK2"),
        ],
        links: [],
        privacyNote: privacyNote,
        notATaxDocumentNote: nil
    )

    static let teenReceipt = Receipt(
        id: "R-260915-04828",
        type: .teenEarnings,
        orderNumber: "0042",
        issuedAt: Date(timeIntervalSince1970: 1_789_000_060),
        identityRows: [
            .init(id: "r1", label: "EARNED BY", value: "@michael"),
            .init(id: "r2", label: "PAID BY", value: "@marcus"),
        ],
        serviceTitle: "Lawn mowing and edging",
        serviceLines: ["Yard work · Northside", "Saturday, 10:00 AM", "Confirmed complete"],
        lines: [
            .init(id: "l1", label: "BASE EARNINGS", amountCents: 2200, emphasis: .normal, note: nil),
            .init(id: "l2", label: "TIP", amountCents: 500, emphasis: .normal, note: "You keep 100% of tips"),
            .init(id: "l3", label: "GROSS EARNINGS", amountCents: 2700, emphasis: .subtotal, note: nil),
            .init(id: "l4", label: "DEDUCTIONS", amountCents: 0, emphasis: .quiet, note: "MORT's fee is paid by the job poster, not you"),
            .init(id: "l5", label: "ADJUSTMENTS", amountCents: 0, emphasis: .quiet, note: nil),
            .init(id: "l6", label: "NET EARNINGS", amountCents: 2700, emphasis: .total, note: nil),
        ],
        statusTone: .success,
        statusLabel: "EARNINGS CREDITED",
        statusSub: "Payout status lives in Job & Payment History",
        methodLabel: nil,
        methodMask: nil,
        referenceRows: [
            .init(id: "ref1", label: "RECEIPT #", value: "R-260915-04828"),
            .init(id: "ref2", label: "ORDER #", value: "0042"),
        ],
        links: [],
        privacyNote: privacyNote,
        notATaxDocumentNote: "This is a record of your MORT earnings. It is not a tax document."
    )

    static let tipReceipt = Receipt(
        id: "Q-260916-04913",
        type: .lateTip,
        orderNumber: "0042",
        issuedAt: Date(timeIntervalSince1970: 1_789_090_000),
        identityRows: [
            .init(id: "r1", label: "TIPPED BY", value: "@marcus"),
            .init(id: "r2", label: "PAID TO", value: "@michael"),
        ],
        serviceTitle: "Lawn mowing and edging",
        serviceLines: ["Tip added after the job was paid"],
        lines: [
            .init(id: "l1", label: "TIP", amountCents: 500, emphasis: .normal, note: "100% to @michael"),
            .init(id: "l2", label: "MORT FEE ON TIP", amountCents: 0, emphasis: .quiet, note: "MORT never takes a cut of a tip"),
            .init(id: "l3", label: "TOTAL", amountCents: 500, emphasis: .total, note: nil),
        ],
        statusTone: .success,
        statusLabel: "TIP PAID",
        statusSub: nil,
        methodLabel: "Visa",
        methodMask: "•••• 4242",
        referenceRows: [
            .init(id: "ref1", label: "RECEIPT #", value: "Q-260916-04913"),
            .init(id: "ref2", label: "ORDER #", value: "0042"),
        ],
        links: [
            .init(
                id: "lk1", title: "ORIGINAL PAYMENT",
                rows: [
                    .init(id: "lr1", label: "RECEIPT #", value: "K-260915-04827"),
                    .init(id: "lr2", label: "TOTAL PAID", value: "$23.76"),
                ],
                status: "Unchanged"
            )
        ],
        privacyNote: privacyNote,
        notATaxDocumentNote: nil
    )

    static let partialRefundReceipt = Receipt(
        id: "P-260918-05103",
        type: .partialRefund,
        orderNumber: "10428",
        issuedAt: Date(timeIntervalSince1970: 1_789_300_000),
        identityRows: [
            .init(id: "r1", label: "REFUNDED TO", value: "@marcus"),
            .init(id: "r2", label: "ORIGINAL WORKER", value: "@michael"),
        ],
        serviceTitle: "Full weekend garage reorganization",
        serviceLines: ["Part of the work wasn't completed", "Settled by MORT review"],
        lines: [
            .init(id: "l1", label: "ORIGINALLY FUNDED", amountCents: 125_075, emphasis: .normal, note: nil),
            .init(id: "l2", label: "COMPENSATED WORK", amountCents: 90_000, emphasis: .normal, note: nil),
            .init(id: "l3", label: "REFUNDED TO YOU", amountCents: 35_075, emphasis: .total, note: nil),
            .init(id: "l4", label: "REMAINING PAID", amountCents: 90_000, emphasis: .subtotal, note: "Still paid to @michael"),
        ],
        statusTone: .info,
        statusLabel: "PARTIALLY REFUNDED",
        statusSub: "The original receipt was not changed",
        methodLabel: "Visa",
        methodMask: "•••• 4242",
        referenceRows: [
            .init(id: "ref1", label: "RECEIPT #", value: "P-260918-05103"),
            .init(id: "ref2", label: "ORDER #", value: "10428"),
        ],
        links: [
            .init(
                id: "lk1", title: "ORIGINAL PAYMENT",
                rows: [
                    .init(id: "lr1", label: "RECEIPT #", value: "M-260918-05102"),
                    .init(id: "lr2", label: "TOTAL PAID", value: "$1,255.75"),
                ],
                status: "Unchanged"
            )
        ],
        privacyNote: privacyNote,
        notATaxDocumentNote: nil
    )

    static let storeReceipt = Receipt(
        id: "V-260921-05367",
        type: .storePurchase,
        orderNumber: "0051",
        issuedAt: Date(timeIntervalSince1970: 1_789_500_000),
        identityRows: [.init(id: "r1", label: "PURCHASED BY", value: "@marcus")],
        serviceTitle: "MORT Plus — monthly",
        serviceLines: ["Billed through the App Store"],
        lines: [
            .init(id: "l1", label: "SUBSCRIPTION", amountCents: 499, emphasis: .normal, note: nil),
            .init(id: "l2", label: "TOTAL", amountCents: 499, emphasis: .total, note: nil),
        ],
        statusTone: .success,
        statusLabel: "PURCHASE CONFIRMED",
        statusSub: "Verified with the App Store",
        methodLabel: "App Store",
        methodMask: "Apple ID on file",
        referenceRows: [
            .init(id: "ref1", label: "RECEIPT #", value: "V-260921-05367"),
            .init(id: "ref2", label: "STORE REF", value: "AS-••••-5367"),
        ],
        links: [],
        privacyNote: privacyNote,
        notATaxDocumentNote: nil
    )

    static let fullRefundReceipt = Receipt(
        id: "D-260920-05341",
        type: .fullRefund,
        orderNumber: "0039",
        issuedAt: Date(timeIntervalSince1970: 1_789_400_000),
        identityRows: [.init(id: "r1", label: "REFUNDED TO", value: "@marcus")],
        serviceTitle: "Window cleaning",
        serviceLines: ["Job cancelled before it started"],
        lines: [
            .init(id: "l1", label: "BASE REFUND", amountCents: 3000, emphasis: .normal, note: nil),
            .init(id: "l2", label: "FEE REFUND", amountCents: 240, emphasis: .normal, note: nil),
            .init(id: "l3", label: "TOTAL REFUNDED", amountCents: 3240, emphasis: .total, note: nil),
        ],
        statusTone: .info,
        statusLabel: "FULLY REFUNDED",
        statusSub: "The original receipt was not changed",
        methodLabel: "Visa",
        methodMask: "•••• 4242",
        referenceRows: [.init(id: "ref1", label: "RECEIPT #", value: "D-260920-05341")],
        links: [
            .init(
                id: "lk1", title: "ORIGINAL PAYMENT",
                rows: [.init(id: "lr1", label: "RECEIPT #", value: "B-260915-04829")],
                status: "Unchanged"
            )
        ],
        privacyNote: privacyNote,
        notATaxDocumentNote: nil
    )

    static let adjustmentReceipt = Receipt(
        id: "A-260922-05402",
        type: .adjustment,
        orderNumber: "0042",
        issuedAt: Date(timeIntervalSince1970: 1_789_600_000),
        identityRows: [
            .init(id: "r1", label: "ADJUSTED FOR", value: "@michael"),
            .init(id: "r2", label: "APPROVED BY", value: "MORT Support"),
        ],
        serviceTitle: "Lawn mowing and edging",
        serviceLines: ["Extra time approved after review"],
        lines: [
            .init(id: "l1", label: "ADJUSTMENT", amountCents: 800, emphasis: .normal, note: "Added to your earnings"),
            .init(id: "l2", label: "TOTAL", amountCents: 800, emphasis: .total, note: nil),
        ],
        statusTone: .success,
        statusLabel: "ADJUSTMENT CREDITED",
        statusSub: "Payout status lives in Job & Payment History",
        methodLabel: nil,
        methodMask: nil,
        referenceRows: [.init(id: "ref1", label: "RECEIPT #", value: "A-260922-05402")],
        links: [
            .init(
                id: "lk1", title: "ORIGINAL EARNINGS",
                rows: [.init(id: "lr1", label: "RECEIPT #", value: "R-260915-04828")],
                status: "Unchanged"
            )
        ],
        privacyNote: privacyNote,
        notATaxDocumentNote: "This is a record of your MORT earnings. It is not a tax document."
    )

    static let reversalReceipt = Receipt(
        id: "W-260923-05480",
        type: .reversal,
        orderNumber: "0036",
        issuedAt: Date(timeIntervalSince1970: 1_789_700_000),
        identityRows: [.init(id: "r1", label: "REVERSED FOR", value: "@marcus")],
        serviceTitle: "Gutter clearing",
        serviceLines: ["Payment reversed by the provider"],
        lines: [
            .init(id: "l1", label: "REVERSED AMOUNT", amountCents: 4500, emphasis: .total, note: nil),
        ],
        statusTone: .warning,
        statusLabel: "REVERSED",
        statusSub: "The original receipt was not changed",
        methodLabel: "Visa",
        methodMask: "•••• 4242",
        referenceRows: [.init(id: "ref1", label: "RECEIPT #", value: "W-260923-05480")],
        links: [
            .init(
                id: "lk1", title: "ORIGINAL PAYMENT",
                rows: [.init(id: "lr1", label: "RECEIPT #", value: "B-260915-04829")],
                status: "Unchanged"
            )
        ],
        privacyNote: privacyNote,
        notATaxDocumentNote: nil
    )

    static let allReceipts: [Receipt] = [
        adultReceipt, teenReceipt, storeReceipt, tipReceipt,
        fullRefundReceipt, partialRefundReceipt, adjustmentReceipt, reversalReceipt,
    ]

    // MARK: - Payout

    static let payout = PayoutStatus(
        id: "po-1",
        stage: .transferPending,
        amountCents: 2700,
        relatedReceiptNumber: "R-260915-04828",
        updatedAt: Date(timeIntervalSince1970: 1_789_100_000),
        destinationMask: "•••• 1881",
        expectedText: "Expected by Thursday"
    )

    // MARK: - History

    static func historyRecords() -> [HistoryRecord] {
        let day: TimeInterval = 86_400
        let now = Date(timeIntervalSince1970: 1_789_700_000)
        return [
            .init(id: "h1", kind: .earning, title: "Lawn mowing and edging", counterpartyHandle: "@marcus",
                  amountCents: 2700, occurredAt: now.addingTimeInterval(-day * 1), statusLabel: "Credited",
                  statusTone: .success, statusSymbol: "checkmark.circle", receiptNumber: "R-260915-04828",
                  orderNumber: "0042", noReceiptIssued: false, jobId: "job-42"),
            .init(id: "h2", kind: .tip, title: "Tip from @marcus", counterpartyHandle: "@marcus",
                  amountCents: 500, occurredAt: now.addingTimeInterval(-day * 1), statusLabel: "Paid",
                  statusTone: .success, statusSymbol: "checkmark.circle", receiptNumber: "Q-260916-04913",
                  orderNumber: "0042", noReceiptIssued: false, jobId: "job-42"),
            .init(id: "h3", kind: .job, title: "Water plants while away", counterpartyHandle: "@sofia",
                  amountCents: 1200, occurredAt: now.addingTimeInterval(-day * 3), statusLabel: "In progress",
                  statusTone: .warning, statusSymbol: "figure.walk.motion", receiptNumber: nil,
                  orderNumber: "0038", noReceiptIssued: false, jobId: "job-30"),
            .init(id: "h4", kind: .payment, title: "Move boxes to storage unit", counterpartyHandle: "@grant",
                  amountCents: -4320, occurredAt: now.addingTimeInterval(-day * 5), statusLabel: "Funded",
                  statusTone: .success, statusSymbol: "lock.shield", receiptNumber: "B-260915-04829",
                  orderNumber: "0035", noReceiptIssued: false, jobId: "job-31"),
            .init(id: "h5", kind: .failedPayment, title: "Window cleaning", counterpartyHandle: "@ellen",
                  amountCents: 0, occurredAt: now.addingTimeInterval(-day * 8), statusLabel: "Declined",
                  statusTone: .danger, statusSymbol: "xmark.circle", receiptNumber: nil,
                  orderNumber: "0039", noReceiptIssued: true, jobId: nil),
            .init(id: "h6", kind: .refund, title: "Window cleaning refund", counterpartyHandle: "@ellen",
                  amountCents: 3240, occurredAt: now.addingTimeInterval(-day * 9), statusLabel: "Refunded",
                  statusTone: .info, statusSymbol: "arrow.uturn.left.circle", receiptNumber: "D-260920-05341",
                  orderNumber: "0039", noReceiptIssued: false, jobId: nil),
            .init(id: "h7", kind: .adjustment, title: "Extra time adjustment", counterpartyHandle: "@michael",
                  amountCents: 800, occurredAt: now.addingTimeInterval(-day * 12), statusLabel: "Credited",
                  statusTone: .success, statusSymbol: "slider.horizontal.3", receiptNumber: "A-260922-05402",
                  orderNumber: "0042", noReceiptIssued: false, jobId: "job-42"),
            .init(id: "h8", kind: .storePurchase, title: "MORT Plus — monthly", counterpartyHandle: "@marcus",
                  amountCents: -499, occurredAt: now.addingTimeInterval(-day * 14), statusLabel: "Confirmed",
                  statusTone: .success, statusSymbol: "bag", receiptNumber: "V-260921-05367",
                  orderNumber: "0051", noReceiptIssued: false, jobId: nil),
            .init(id: "h9", kind: .dispute, title: "Full weekend garage reorganization", counterpartyHandle: "@christopher_bartholomew",
                  amountCents: -125_075, occurredAt: now.addingTimeInterval(-day * 40), statusLabel: "Disputed",
                  statusTone: .danger, statusSymbol: "exclamationmark.triangle", receiptNumber: "M-260918-05102",
                  orderNumber: "10428", noReceiptIssued: false, jobId: "job-99"),
            .init(id: "h10", kind: .refund, title: "Partial refund — garage job", counterpartyHandle: "@christopher_bartholomew",
                  amountCents: 35_075, occurredAt: now.addingTimeInterval(-day * 39), statusLabel: "Partially refunded",
                  statusTone: .info, statusSymbol: "arrow.uturn.left.circle", receiptNumber: "P-260918-05103",
                  orderNumber: "10428", noReceiptIssued: false, jobId: "job-99"),
            .init(id: "h11", kind: .earning, title: "Grocery run for neighbor", counterpartyHandle: "@nina",
                  amountCents: 1500, occurredAt: now.addingTimeInterval(-day * 65), statusLabel: "Paid out",
                  statusTone: .success, statusSymbol: "checkmark.circle", receiptNumber: "N-260712-03980",
                  orderNumber: "0031", noReceiptIssued: false, jobId: "job-32"),
            .init(id: "h12", kind: .earning, title: "Bookshelf assembly help", counterpartyHandle: "@theo",
                  amountCents: 2200, occurredAt: now.addingTimeInterval(-day * 120), statusLabel: "Paid out",
                  statusTone: .success, statusSymbol: "checkmark.circle", receiptNumber: "T-260518-02714",
                  orderNumber: "0022", noReceiptIssued: false, jobId: nil),
        ]
    }

    /// A large synthetic feed used to verify the timeline scales past 100 rows
    /// without becoming a wall of identical cards.
    static func largeHistoryFeed(count: Int = 140) -> [HistoryRecord] {
        let base = historyRecords()
        let day: TimeInterval = 86_400
        return (0..<count).map { i in
            let seed = base[i % base.count]
            return HistoryRecord(
                id: "gen-\(i)",
                kind: seed.kind,
                title: seed.title,
                counterpartyHandle: seed.counterpartyHandle,
                amountCents: seed.amountCents,
                occurredAt: seed.occurredAt.addingTimeInterval(-day * Double(i) * 1.7),
                statusLabel: seed.statusLabel,
                statusTone: seed.statusTone,
                statusSymbol: seed.statusSymbol,
                receiptNumber: seed.receiptNumber.map { "\($0)-\(i)" },
                orderNumber: seed.orderNumber,
                noReceiptIssued: seed.noReceiptIssued,
                jobId: seed.jobId
            )
        }
    }

    // MARK: - Messaging

    static let conversations: [MortConversation] = [
        .init(id: "c1", counterpartyHandle: "@marcus", counterpartyDisplayName: "Marcus T.",
              counterpartyInitials: "MT", preview: "Perfect — see you Saturday at 10.",
              updatedAt: Date(timeIntervalSince1970: 1_789_690_000), unreadCount: 2,
              jobTitle: "Lawn mowing and edging", jobId: "job-42", restriction: .none),
        .init(id: "c2", counterpartyHandle: "@sofia", counterpartyDisplayName: "Sofia L.",
              counterpartyInitials: "SL", preview: "That works, thank you!",
              updatedAt: Date(timeIntervalSince1970: 1_789_600_000), unreadCount: 0,
              jobTitle: "Water plants while away", jobId: "job-30", restriction: .none),
        .init(id: "c3", counterpartyHandle: "@nina", counterpartyDisplayName: "Nina W.",
              counterpartyInitials: "NW", preview: "Thanks again for the help.",
              updatedAt: Date(timeIntervalSince1970: 1_789_100_000), unreadCount: 0,
              jobTitle: "Grocery run for neighbor", jobId: "job-32", restriction: .archived),
    ]

    static let messages: [MortMessage] = [
        .init(id: "m1", conversationId: "c1", authorHandle: "@marcus", authorDisplayName: "Marcus T.",
              body: "Hey! Are you still good for Saturday at 10?",
              sentAt: Date(timeIntervalSince1970: 1_789_680_000), fromMe: false,
              delivery: .read, attachmentName: nil),
        .init(id: "m2", conversationId: "c1", authorHandle: "@michael", authorDisplayName: "Michael R.",
              body: "Yes — I'll be there a few minutes early.",
              sentAt: Date(timeIntervalSince1970: 1_789_681_000), fromMe: true,
              delivery: .read, attachmentName: nil),
        .init(id: "m3", conversationId: "c1", authorHandle: "@marcus", authorDisplayName: "Marcus T.",
              body: "Perfect — see you Saturday at 10. The mower is in the garage, I'll leave it unlocked.",
              sentAt: Date(timeIntervalSince1970: 1_789_690_000), fromMe: false,
              delivery: .delivered, attachmentName: nil),
    ]

    // MARK: - Safety / Support / Notifications

    static let checkIn = SafetyCheckIn(
        id: "ci-1", jobId: "job-30", jobTitle: "Water plants while away",
        state: .dueSoon, dueAt: Date().addingTimeInterval(1800), confirmedAt: nil
    )

    static let safetyContacts: [SafetyContact] = [
        .init(id: "sc1", displayName: "Dana K.", relationship: "Guardian", contactMask: "•••• 4471", isGuardian: true, isNotifiedOnJobs: true),
        .init(id: "sc2", displayName: "Alex R.", relationship: "Trusted adult", contactMask: "•••• 2210", isGuardian: false, isNotifiedOnJobs: false),
    ]

    static let supportCases: [SupportCase] = [
        .init(id: "sup1", subject: "Refund on the garage job", state: .withSupport,
              updatedAt: Date(timeIntervalSince1970: 1_789_600_000),
              lastMessagePreview: "We've asked the poster for more detail and will update you here.",
              withHumanAgent: true, reference: "P-260918-05103"),
        .init(id: "sup2", subject: "Can't add a payout account", state: .waitingOnYou,
              updatedAt: Date(timeIntervalSince1970: 1_789_300_000),
              lastMessagePreview: "Could you confirm which bank you're trying to add?",
              withHumanAgent: true, reference: nil),
        .init(id: "sup3", subject: "How do tips work?", state: .resolved,
              updatedAt: Date(timeIntervalSince1970: 1_789_000_000),
              lastMessagePreview: "100% of a tip goes to the teen — MORT takes nothing from it.",
              withHumanAgent: false, reference: nil),
    ]

    static let notifications: [MortNotification] = [
        .init(id: "n1", category: .payment, title: "Job funded",
              body: "@marcus funded Lawn mowing and edging. You're good to start.",
              receivedAt: Date().addingTimeInterval(-3600), isRead: false, route: "/jobs/job-42"),
        .init(id: "n2", category: .message, title: "New message from @marcus",
              body: "Perfect — see you Saturday at 10.",
              receivedAt: Date().addingTimeInterval(-7200), isRead: false, route: "/messages/c1"),
        .init(id: "n3", category: .payout, title: "Transfer on the way",
              body: "$27.00 is heading to your payout account.",
              receivedAt: Date().addingTimeInterval(-86_400), isRead: true, route: "/history/payouts"),
        .init(id: "n4", category: .safety, title: "Check-in due soon",
              body: "Your check-in for Water plants while away is due in 30 minutes.",
              receivedAt: Date().addingTimeInterval(-90_000), isRead: true, route: "/safety"),
        .init(id: "n5", category: .application, title: "You were selected",
              body: "@marcus accepted your application for Lawn mowing and edging.",
              receivedAt: Date().addingTimeInterval(-172_800), isRead: true, route: "/jobs/job-42"),
    ]

    static let categories = [
        "Yard work", "Pet care", "Babysitting", "Tech help",
        "Tutoring", "Delivery", "Cleaning", "Events",
    ]
}
