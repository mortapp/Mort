//
//  MortJobCard.swift
//  MORT
//

import SwiftUI

struct MortJobCard: View {
    let job: Job
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack(spacing: MortSpacing.sm) {
                    Image(systemName: job.category.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MortColor.roseGold)
                        .frame(width: 38, height: 38)
                        .background(MortColor.roseGold.opacity(0.14))
                        .clipShape(.rect(cornerRadius: MortRadius.sm))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.title)
                            .font(MortFont.headline())
                            .foregroundStyle(MortColor.primaryText)
                            .lineLimit(1)
                        Text(job.category.label)
                            .font(MortFont.caption())
                            .foregroundStyle(MortColor.secondaryText)
                    }
                    Spacer()
                    MortBadge.forStatus(job.status)
                }

                Text(job.description)
                    .font(MortFont.callout())
                    .foregroundStyle(MortColor.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: MortSpacing.md) {
                    Label(job.locationLabel, systemImage: "mappin.and.ellipse")
                    Label(job.estimatedPayText, systemImage: "dollarsign.circle")
                }
                .font(MortFont.caption())
                .foregroundStyle(MortColor.silver)
            }
            .padding(MortSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mortSurface()
        }
        .buttonStyle(.plain)
    }
}
