//
//  ReceiptPaper.swift
//  MORT iOS V8 — Receipt Components
//
//  The receipt must feel like a REAL receipt, not another app card:
//  warm off-white paper inside the dark shell, perforated edges, monospaced
//  tabular money, dashed rules, dominant ORDER # hierarchy.
//
//  No glassmorphism. No gradients. No card clutter. Receipts are IMMUTABLE:
//  these views render a backend-issued document and never mutate it.
//

import SwiftUI

/// Perforated paper edge (torn receipt look).
private struct PerforatedEdge: View {
    var flipped: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let notch: CGFloat = 9
            let count = max(Int(w / notch), 1)
            Path { path in
                path.move(to: .init(x: 0, y: flipped ? notch : 0))
                for i in 0...count {
                    let x = CGFloat(i) * notch
                    let y: CGFloat = i % 2 == 0 ? (flipped ? 0 : notch) : (flipped ? notch : 0)
                    path.addLine(to: .init(x: x, y: y))
                }
                path.addLine(to: .init(x: w, y: flipped ? 0 : notch))
                path.addLine(to: .init(x: w, y: flipped ? notch : 0))
                path.closeSubpath()
            }
            .fill(MortColor.paper)
        }
        .frame(height: 9)
        .accessibilityHidden(true)
    }
}

/// Dashed separator rule printed on the paper.
struct ReceiptRule: View {
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 1)
            .overlay {
                Rectangle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                    .foregroundStyle(MortColor.paperRule)
                    .frame(height: 1)
            }
            .padding(.vertical, MortSpace.s2)
            .accessibilityHidden(true)
    }
}

/// The paper surface. Wrap receipt content in this.
struct ReceiptPaper<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            PerforatedEdge()
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, MortSpace.s5)
            .padding(.vertical, MortSpace.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MortColor.paper)
            PerforatedEdge(flipped: true)
        }
        .background(MortColor.paper)
        .clipShape(.rect(cornerRadius: 3))
        .shadow(color: .black.opacity(0.5), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Receipt document")
    }
}

/// MORT header printed at the top of every receipt, with the explicit
/// document type title. The leading receipt letter is random and is NEVER
/// styled or interpreted by type.
struct ReceiptHeader: View {
    let documentTitle: String

    var body: some View {
        VStack(spacing: MortSpace.s1) {
            Text("MORT")
                .font(.system(size: 22, weight: .semibold))
                .tracking(6)
                .foregroundStyle(MortColor.paperInk)
            Text("GET IN MOTION")
                .font(.system(size: 9, weight: .medium))
                .tracking(3)
                .foregroundStyle(MortColor.paperInkSoft)
            Text(documentTitle)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(MortColor.paperInk)
                .padding(.top, MortSpace.s3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Giant ORDER # with the receipt number beneath — the strongest hierarchy on
/// the paper after the total.
struct ReceiptOrderNumber: View {
    let orderNumber: String
    let receiptNumber: String

    var body: some View {
        VStack(spacing: MortSpace.s1) {
            Text("ORDER #")
                .font(.system(size: 9, weight: .semibold))
                .tracking(2)
                .foregroundStyle(MortColor.paperInkSoft)
            Text(orderNumber)
                .font(MortFont.money(38, weight: .semibold))
                .foregroundStyle(MortColor.paperInk)
                // Large order numbers must never overflow the paper.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("RECEIPT #\(receiptNumber)")
                .font(MortFont.money(11))
                .foregroundStyle(MortColor.paperInkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Order number \(orderNumber), receipt number \(receiptNumber)")
    }
}

/// Timestamp line. The backend timestamp is authoritative; display converts
/// to device-local time.
struct ReceiptMeta: View {
    let issuedAtText: String

    var body: some View {
        Text(issuedAtText)
            .font(MortFont.money(10))
            .foregroundStyle(MortColor.paperInkSoft)
            .frame(maxWidth: .infinity)
    }
}

/// Key/value identity or reference block printed on paper.
struct ReceiptRowsBlock: View {
    let rows: [ReceiptRow]

    var body: some View {
        VStack(spacing: MortSpace.s2) {
            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline, spacing: MortSpace.s3) {
                    Text(row.label)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(MortColor.paperInkSoft)
                    Spacer(minLength: MortSpace.s2)
                    Text(row.value)
                        .font(MortFont.money(12))
                        .foregroundStyle(MortColor.paperInk)
                        .multilineTextAlignment(.trailing)
                        // Long handles and references wrap, never clip.
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The service description block: title plus up to three lines.
struct ReceiptServiceBlock: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s1) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MortColor.paperInk)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 11))
                    .foregroundStyle(MortColor.paperInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One printed money line. Money is monospaced and right-aligned so every
/// column lines up exactly.
struct ReceiptLineView: View {
    let line: ReceiptLine

    private var labelFont: Font {
        switch line.emphasis {
        case .total: .system(size: 12, weight: .semibold)
        case .subtotal: .system(size: 11, weight: .semibold)
        case .normal: .system(size: 11, weight: .medium)
        case .quiet: .system(size: 10, weight: .regular)
        }
    }

    private var amountFont: Font {
        switch line.emphasis {
        // The TOTAL is the largest type on the paper.
        case .total: MortFont.money(22, weight: .semibold)
        case .subtotal: MortFont.money(14, weight: .medium)
        case .normal: MortFont.money(13)
        case .quiet: MortFont.money(11)
        }
    }

    private var ink: Color {
        line.emphasis == .quiet ? MortColor.paperInkSoft : MortColor.paperInk
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: MortSpace.s3) {
                Text(line.label)
                    .font(labelFont)
                    .tracking(line.emphasis == .total ? 1.0 : 0.5)
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: MortSpace.s2)
                if let amount = line.amount {
                    Text(amount.formatted)
                        .font(amountFont)
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            if let note = line.note {
                Text(note)
                    .font(.system(size: 9))
                    .foregroundStyle(MortColor.paperInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, line.emphasis == .total ? MortSpace.s1 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// Status printed on the paper: tint + icon + label (never color alone).
struct ReceiptStatusView: View {
    let tone: MortTone
    let label: String
    var sub: String?

    private var symbol: String {
        switch tone {
        case .success: "checkmark.circle.fill"
        case .danger: "xmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .info: "arrow.uturn.left.circle.fill"
        case .neutral: "circle.fill"
        }
    }

    var body: some View {
        VStack(spacing: MortSpace.s1) {
            HStack(spacing: MortSpace.s2) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(tone.paperColor)
            if let sub {
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundStyle(MortColor.paperInkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, MortSpace.s2)
        .padding(.horizontal, MortSpace.s3)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 3)
                .fill(tone.paperColor.opacity(0.08))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(label). \(sub ?? "")")
    }
}

/// Masked payment method printed on the paper. [PRIVACY] masks only.
struct ReceiptMethodView: View {
    let label: String
    let mask: String

    var body: some View {
        HStack(spacing: MortSpace.s2) {
            Text("PAID WITH")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(MortColor.paperInkSoft)
            Spacer(minLength: MortSpace.s2)
            Text("\(label) \(mask)")
                .font(MortFont.money(11))
                .foregroundStyle(MortColor.paperInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Linked-document box — this component IS the immutability chain made
/// visible. The parent is always described as "Unchanged".
struct ReceiptLinkedDocument: View {
    let link: ReceiptLink

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            Text(link.title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(MortColor.paperInkSoft)
            ForEach(link.rows) { row in
                HStack(alignment: .firstTextBaseline, spacing: MortSpace.s2) {
                    Text(row.label)
                        .font(.system(size: 9))
                        .foregroundStyle(MortColor.paperInkSoft)
                    Spacer(minLength: MortSpace.s2)
                    Text(row.value)
                        .font(MortFont.money(11))
                        .foregroundStyle(MortColor.paperInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: MortSpace.s1 + 2) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8, weight: .semibold))
                Text(link.status.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
            }
            .foregroundStyle(MortColor.paperInkSoft)
        }
        .padding(MortSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
                .foregroundStyle(MortColor.paperRule)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Privacy footer printed on every receipt.
struct ReceiptPrivacyNote: View {
    let text: String
    var notATaxDocument: String?

    var body: some View {
        VStack(spacing: MortSpace.s2) {
            if let notATaxDocument {
                Text(notATaxDocument)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MortColor.paperInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(text)
                .font(.system(size: 8))
                .foregroundStyle(MortColor.paperInkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The single typed receipt renderer. Every document category flows through
/// this view, fed by a backend-issued `Receipt`.
struct ReceiptDocumentView: View {
    let receipt: Receipt

    var body: some View {
        ReceiptPaper {
            ReceiptHeader(documentTitle: receipt.type.documentTitle)
            ReceiptRule()
            ReceiptOrderNumber(orderNumber: receipt.orderNumber, receiptNumber: receipt.id)
            ReceiptMeta(issuedAtText: receipt.issuedAtText)
            ReceiptRule()
            ReceiptRowsBlock(rows: receipt.identityRows)
            ReceiptRule()
            ReceiptServiceBlock(title: receipt.serviceTitle, lines: receipt.serviceLines)
            ReceiptRule()
            VStack(spacing: MortSpace.s1) {
                ForEach(receipt.lines) { line in
                    if line.emphasis == .total {
                        ReceiptRule()
                    }
                    ReceiptLineView(line: line)
                }
            }
            ReceiptRule()
            ReceiptStatusView(
                tone: receipt.statusTone,
                label: receipt.statusLabel,
                sub: receipt.statusSub
            )
            if let label = receipt.methodLabel, let mask = receipt.methodMask {
                ReceiptRule()
                ReceiptMethodView(label: label, mask: mask)
            }
            if !receipt.referenceRows.isEmpty {
                ReceiptRule()
                ReceiptRowsBlock(rows: receipt.referenceRows)
            }
            if !receipt.links.isEmpty {
                ReceiptRule()
                VStack(spacing: MortSpace.s2) {
                    ForEach(receipt.links) { link in
                        ReceiptLinkedDocument(link: link)
                    }
                }
            }
            ReceiptRule()
            ReceiptPrivacyNote(
                text: receipt.privacyNote,
                notATaxDocument: receipt.notATaxDocumentNote
            )
        }
    }
}

#Preview("Adult receipt") {
    ZStack {
        MortAtmosphere(intensity: 0.7)
        ScrollView {
            ReceiptDocumentView(receipt: MortFixtures.adultReceipt)
                .padding()
        }
    }
}

#Preview("Teen earnings receipt") {
    ZStack {
        MortAtmosphere(intensity: 0.7)
        ScrollView {
            ReceiptDocumentView(receipt: MortFixtures.teenReceipt)
                .padding()
        }
    }
}
