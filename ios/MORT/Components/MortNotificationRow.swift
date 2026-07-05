//
//  MortNotificationRow.swift
//  MORT
//

import SwiftUI

struct MortNotificationRow: View {
    let item: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: MortSpacing.sm) {
            Image(systemName: item.kind.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MortColor.roseGold)
                .frame(width: 38, height: 38)
                .background(MortColor.roseGold.opacity(0.14))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(MortFont.headline())
                    .foregroundStyle(MortColor.primaryText)
                Text(item.body)
                    .font(MortFont.callout())
                    .foregroundStyle(MortColor.secondaryText)
                    .multilineTextAlignment(.leading)
                Text(item.createdAt, style: .relative)
                    .font(MortFont.caption())
                    .foregroundStyle(MortColor.darkSilver)
            }
            Spacer(minLength: 0)
            if !item.read {
                Circle()
                    .fill(MortColor.roseGold)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(MortSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mortSurface()
    }
}
