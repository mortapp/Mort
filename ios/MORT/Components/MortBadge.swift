//
//  MortBadge.swift
//  MORT
//

import SwiftUI

struct MortBadge: View {
    let text: String
    var color: Color = MortColor.roseGold
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(MortFont.tiny())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14))
        .clipShape(.rect(cornerRadius: MortRadius.pill))
    }
}

extension MortBadge {
    static func forStatus(_ status: JobStatus) -> MortBadge {
        switch status {
        case .open: return MortBadge(text: status.label, color: MortColor.success)
        case .inProgress: return MortBadge(text: status.label, color: MortColor.warning)
        case .completed: return MortBadge(text: status.label, color: MortColor.silver)
        case .closed: return MortBadge(text: status.label, color: MortColor.darkSilver)
        }
    }

    static func forApplication(_ status: ApplicationStatus) -> MortBadge {
        switch status {
        case .pending: return MortBadge(text: status.label, color: MortColor.warning)
        case .accepted: return MortBadge(text: status.label, color: MortColor.success)
        case .declined: return MortBadge(text: status.label, color: MortColor.danger)
        case .withdrawn: return MortBadge(text: status.label, color: MortColor.darkSilver)
        }
    }

    static func forReport(_ status: ReportStatus) -> MortBadge {
        switch status {
        case .open: return MortBadge(text: status.label, color: MortColor.danger)
        case .reviewing: return MortBadge(text: status.label, color: MortColor.warning)
        case .resolved: return MortBadge(text: status.label, color: MortColor.success)
        case .dismissed: return MortBadge(text: status.label, color: MortColor.darkSilver)
        }
    }
}
