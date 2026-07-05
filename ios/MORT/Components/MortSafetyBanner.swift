//
//  MortSafetyBanner.swift
//  MORT
//

import SwiftUI

struct MortSafetyBanner: View {
    var result: SafetyScanResult? = nil
    var staticMessage: String? = nil

    private var severity: SafetySeverity { result?.severity ?? .warn }

    private var tint: Color {
        switch severity {
        case .safe: return MortColor.success
        case .warn: return MortColor.warning
        case .block: return MortColor.danger
        }
    }

    private var icon: String {
        switch severity {
        case .safe: return "checkmark.shield.fill"
        case .warn: return "exclamationmark.shield.fill"
        case .block: return "xmark.shield.fill"
        }
    }

    private var text: String {
        if let staticMessage { return staticMessage }
        return result?.message ?? mortSafetyWarning
    }

    var body: some View {
        HStack(alignment: .top, spacing: MortSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(MortFont.callout())
                    .foregroundStyle(MortColor.primaryText)
                if let result, !result.matches.isEmpty {
                    Text(result.matches.map(\.category).joined(separator: " • "))
                        .font(MortFont.caption())
                        .foregroundStyle(MortColor.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(MortSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .clipShape(.rect(cornerRadius: MortRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: MortRadius.sm)
                .stroke(tint.opacity(0.4), lineWidth: 1)
        )
    }
}
