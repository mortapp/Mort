//
//  MortTopBar.swift
//  MORT
//

import SwiftUI

struct MortTopBar: View {
    let title: String
    var subtitle: String? = nil
    var trailingSystemImage: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MortFont.title())
                    .foregroundStyle(MortColor.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(MortFont.caption())
                        .foregroundStyle(MortColor.secondaryText)
                }
            }
            Spacer()
            if let trailingSystemImage, let trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MortColor.primaryText)
                        .frame(width: 44, height: 44)
                        .background(MortColor.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MortColor.stroke, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, MortSpacing.md)
        .padding(.vertical, MortSpacing.sm)
    }
}
