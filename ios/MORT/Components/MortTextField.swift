//
//  MortTextField.swift
//  MORT
//

import SwiftUI

struct MortTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var systemImage: String? = nil
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var helper: String? = nil
    var characterLimit: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            Text(title.uppercased())
                .font(MortFont.tiny())
                .foregroundStyle(MortColor.darkSilver)
                .tracking(0.8)

            HStack(spacing: MortSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(MortColor.roseGold)
                        .frame(width: 20)
                }
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(MortFont.body())
                .foregroundStyle(MortColor.primaryText)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .onChange(of: text) { _, newValue in
                    if let limit = characterLimit, newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                }
            }
            .padding(.horizontal, MortSpacing.md)
            .padding(.vertical, 14)
            .background(MortColor.surface)
            .clipShape(.rect(cornerRadius: MortRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: MortRadius.sm)
                    .stroke(MortColor.stroke, lineWidth: 1)
            )

            if let helper {
                Text(helper)
                    .font(MortFont.caption())
                    .foregroundStyle(MortColor.darkSilver)
            }
        }
    }
}
