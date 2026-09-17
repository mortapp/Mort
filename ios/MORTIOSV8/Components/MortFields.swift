//
//  MortFields.swift
//  MORT iOS V8 — Components
//
//  Text, secure, search and money fields on graphite surfaces. All controls
//  meet the 44pt minimum and expose proper accessibility labels.
//

import SwiftUI

/// Standard labeled text field.
struct MortTextField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var symbol: String?
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var submitLabel: SubmitLabel = .return
    var errorText: String?
    var helpText: String?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            Text(label.uppercased())
                .mortEyebrow()

            HStack(spacing: MortSpace.s2) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MortColor.textMuted)
                        .frame(width: 18)
                }
                TextField(placeholder, text: $text)
                    .focused($focused)
                    .font(MortFont.body())
                    .foregroundStyle(MortColor.textPrimary)
                    .tint(MortColor.silver3)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(keyboard == .emailAddress)
                    .submitLabel(submitLabel)
            }
            .padding(.horizontal, MortSpace.s3)
            .frame(minHeight: MortMetric.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .fill(MortColor.graphite2.opacity(0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .strokeBorder(
                        errorText != nil
                            ? MortColor.danger.opacity(0.7)
                            : (focused ? MortColor.borderSilver : MortColor.borderGraphite2),
                        lineWidth: 1
                    )
            }

            if let errorText {
                MortNote(text: errorText, tone: .danger)
            } else if let helpText {
                MortNote(text: helpText, tone: .neutral)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// Secure field with a reveal toggle.
struct MortSecureField: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var errorText: String?
    var helpText: String?

    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            Text(label.uppercased())
                .mortEyebrow()

            HStack(spacing: MortSpace.s2) {
                Image(systemName: "lock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MortColor.textMuted)
                    .frame(width: 18)

                Group {
                    if revealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .focused($focused)
                .font(MortFont.body())
                .foregroundStyle(MortColor.textPrimary)
                .tint(MortColor.silver3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    revealed.toggle()
                    MortHaptic.select()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MortColor.textSecondary)
                        .frame(width: MortMetric.minTouchTarget, height: MortMetric.minTouchTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(revealed ? "Hide password" : "Show password")
            }
            .padding(.leading, MortSpace.s3)
            .frame(minHeight: MortMetric.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .fill(MortColor.graphite2.opacity(0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .strokeBorder(
                        errorText != nil
                            ? MortColor.danger.opacity(0.7)
                            : (focused ? MortColor.borderSilver : MortColor.borderGraphite2),
                        lineWidth: 1
                    )
            }

            if let errorText {
                MortNote(text: errorText, tone: .danger)
            } else if let helpText {
                MortNote(text: helpText, tone: .neutral)
            }
        }
    }
}

/// Multi-line field for job descriptions and messages to support.
struct MortTextArea: View {
    let label: String
    var placeholder: String = ""
    @Binding var text: String
    var minHeight: CGFloat = 108
    var helpText: String?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            Text(label.uppercased()).mortEyebrow()

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(MortFont.body())
                        .foregroundStyle(MortColor.textMuted)
                        .padding(.horizontal, MortSpace.s3 + 1)
                        .padding(.vertical, MortSpace.s3)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .font(MortFont.body())
                    .foregroundStyle(MortColor.textPrimary)
                    .tint(MortColor.silver3)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, MortSpace.s2 + 2)
                    .padding(.vertical, MortSpace.s2 + 2)
            }
            .frame(minHeight: minHeight)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .fill(MortColor.graphite2.opacity(0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .strokeBorder(focused ? MortColor.borderSilver : MortColor.borderGraphite2, lineWidth: 1)
            }

            if let helpText {
                MortNote(text: helpText, tone: .neutral)
            }
        }
    }
}

/// Search field used by discovery and history.
struct MortSearchField: View {
    var placeholder: String = "Search"
    @Binding var text: String
    var onSubmit: (() -> Void)?

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: MortSpace.s2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MortColor.textMuted)
            TextField(placeholder, text: $text)
                .focused($focused)
                .font(MortFont.body())
                .foregroundStyle(MortColor.textPrimary)
                .tint(MortColor.silver3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { onSubmit?() }
            if !text.isEmpty {
                Button {
                    text = ""
                    MortHaptic.select()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MortColor.textMuted)
                        .frame(width: MortMetric.minTouchTarget, height: MortMetric.minTouchTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, MortSpace.s3)
        .padding(.trailing, text.isEmpty ? MortSpace.s3 : 0)
        .frame(minHeight: MortMetric.controlHeight)
        .background {
            RoundedRectangle(cornerRadius: MortRadius.pill, style: .continuous)
                .fill(MortColor.graphite2.opacity(0.9))
        }
        .overlay {
            RoundedRectangle(cornerRadius: MortRadius.pill, style: .continuous)
                .strokeBorder(focused ? MortColor.borderSilver : MortColor.borderGraphite2, lineWidth: 1)
        }
        .accessibilityLabel(placeholder)
    }
}

/// Money entry field. Monospaced, decimal keypad, live invalid-character
/// stripping. Amounts are handled as integer cents by the caller.
struct MortMoneyField: View {
    let label: String
    @Binding var text: String
    var tone: MortTone = .neutral
    var message: String?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            Text(label.uppercased()).mortEyebrow()

            HStack(spacing: MortSpace.s1) {
                Text("$")
                    .font(MortFont.money(28, weight: .light))
                    .foregroundStyle(MortColor.textSecondary)
                TextField("0.00", text: $text)
                    .focused($focused)
                    .font(MortFont.money(28, weight: .regular))
                    .foregroundStyle(MortColor.textPrimary)
                    .tint(MortColor.silver3)
                    .keyboardType(.decimalPad)
                    .onChange(of: text) { _, newValue in
                        // Live-strip anything that isn't a digit or a single dot.
                        var filtered = newValue.filter { $0.isNumber || $0 == "." }
                        let parts = filtered.split(separator: ".", omittingEmptySubsequences: false)
                        if parts.count > 2 {
                            filtered = parts[0] + "." + parts[1]
                        }
                        if let dot = filtered.firstIndex(of: "."),
                           filtered.distance(from: dot, to: filtered.endIndex) > 3 {
                            filtered = String(filtered.prefix(upTo: filtered.index(dot, offsetBy: 3)))
                        }
                        if filtered != newValue { text = filtered }
                    }
                    .accessibilityLabel("\(label) in dollars")
            }
            .padding(.horizontal, MortSpace.s4)
            .frame(minHeight: 68)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                    .fill(MortColor.graphite2.opacity(0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                    .strokeBorder(
                        tone == .neutral
                            ? (focused ? MortColor.borderSilver : MortColor.borderGraphite2)
                            : tone.color.opacity(0.65),
                        lineWidth: 1
                    )
            }

            if let message {
                MortNote(text: message, tone: tone)
            }
        }
    }
}

/// Selectable chip used for filters, categories and tip options.
struct MortChip: View {
    let label: String
    var symbol: String?
    var isSelected: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            MortHaptic.select()
            action()
        } label: {
            HStack(spacing: MortSpace.s1 + 2) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? MortColor.ink1 : MortColor.textSecondary)
            .padding(.horizontal, MortSpace.s3 + 2)
            // 44pt minimum height — accessibility target law.
            .frame(minHeight: MortMetric.minTouchTarget)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? MortColor.silver2 : MortColor.graphite2.opacity(0.85))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? MortColor.white.opacity(0.4) : MortColor.borderGraphite2,
                        lineWidth: 1
                    )
            }
            .opacity(isEnabled ? 1 : 0.38)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Avatar with initials. Never renders a photo we don't have.
struct MortAvatar: View {
    let initials: String
    var size: CGFloat = 40
    var tone: MortTone?

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [MortColor.graphite4, MortColor.graphite2],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Circle().strokeBorder(MortColor.hairline2, lineWidth: 1)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(MortColor.silver3)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if let tone {
                Circle()
                    .fill(tone.color)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .overlay { Circle().strokeBorder(MortColor.ink1, lineWidth: 1.5) }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Labeled key/value row used across details, settings and summaries.
struct MortKeyValueRow: View {
    let label: String
    let value: String
    var valueTone: Color = MortColor.textPrimary
    var isMonospaced: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MortSpace.s3) {
            Text(label)
                .mortLabel()
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: MortSpace.s2)
            Text(value)
                .font(isMonospaced ? MortFont.money(14) : MortFont.bodyStrong())
                .foregroundStyle(valueTone)
                .multilineTextAlignment(.trailing)
                // Long values wrap instead of overflowing or clipping.
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, MortSpace.s1)
        .accessibilityElement(children: .combine)
    }
}

/// Copyable reference row (receipt numbers, support references).
struct MortCopyRow: View {
    let label: String
    let value: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: MortSpace.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased()).mortEyebrow()
                Text(value)
                    .font(MortFont.money(14))
                    .foregroundStyle(MortColor.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: MortSpace.s2)
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = value
                #endif
                MortHaptic.success()
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            } label: {
                HStack(spacing: MortSpace.s1) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                    Text(copied ? "Copied" : "Copy")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(copied ? MortColor.success : MortColor.silver3)
                .padding(.horizontal, MortSpace.s3)
                .frame(minHeight: MortMetric.minTouchTarget)
                .background { Capsule().fill(MortColor.graphite3.opacity(0.9)) }
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(label)")
        }
        .padding(.vertical, MortSpace.s1)
    }
}

/// Settings-style toggle row.
struct MortToggleRow: View {
    let title: String
    var detail: String?
    var symbol: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: MortSpace.s3) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MortColor.silver1)
                    .frame(width: 22)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).mortBodyStrong()
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail).mortMicro()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: MortSpace.s2)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(MortColor.silver2)
        }
        .frame(minHeight: MortMetric.minTouchTarget)
        .padding(.vertical, MortSpace.s2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// Navigation row used by settings and profile menus.
struct MortNavRow: View {
    let title: String
    var detail: String?
    var symbol: String?
    var trailingText: String?
    var tone: MortTone?
    let action: () -> Void

    var body: some View {
        Button {
            MortHaptic.tap()
            action()
        } label: {
            HStack(spacing: MortSpace.s3) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(tone?.color ?? MortColor.silver1)
                        .frame(width: 22)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MortFont.bodyStrong())
                        .foregroundStyle(tone?.color ?? MortColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail).mortMicro()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: MortSpace.s2)
                if let trailingText {
                    Text(trailingText)
                        .mortLabel()
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MortColor.textMuted)
            }
            .frame(minHeight: MortMetric.minTouchTarget)
            .padding(.vertical, MortSpace.s2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}
