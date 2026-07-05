//
//  MortRoleCard.swift
//  MORT
//

import SwiftUI

struct MortRoleCard: View {
    let role: UserRole
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MortSpacing.md) {
                Image(systemName: role.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? MortColor.productionBlack : MortColor.roseGold)
                    .frame(width: 52, height: 52)
                    .background(isSelected ? AnyShapeStyle(MortColor.roseGold) : AnyShapeStyle(MortColor.roseGold.opacity(0.14)))
                    .clipShape(.rect(cornerRadius: MortRadius.sm))

                VStack(alignment: .leading, spacing: 3) {
                    Text(role.title)
                        .font(MortFont.headline())
                        .foregroundStyle(MortColor.primaryText)
                    Text(role.subtitle)
                        .font(MortFont.caption())
                        .foregroundStyle(MortColor.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(isSelected ? MortColor.roseGold : MortColor.darkSilver)
            }
            .padding(MortSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MortColor.surface)
            .clipShape(.rect(cornerRadius: MortRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MortRadius.md)
                    .stroke(isSelected ? MortColor.roseGold : MortColor.stroke, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
