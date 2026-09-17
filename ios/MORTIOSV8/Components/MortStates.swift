//
//  MortStates.swift
//  MORT iOS V8 — Components
//
//  Empty, loading, error and offline states. Skeletons NEVER fabricate
//  content — they are clearly shapes, not fake data.
//

import SwiftUI

/// Constructive empty state: says what's missing and offers the next step.
struct MortEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: MortSpace.s4) {
            ZStack {
                Circle()
                    .fill(MortColor.graphite2.opacity(0.8))
                    .frame(width: 66, height: 66)
                Circle()
                    .strokeBorder(MortColor.hairline2, lineWidth: 1)
                    .frame(width: 66, height: 66)
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(MortColor.silver1)
            }
            VStack(spacing: MortSpace.s2) {
                Text(title)
                    .mortH2()
                    .multilineTextAlignment(.center)
                Text(message)
                    .mortBody()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                MortPrimaryButton(title: actionTitle, action: action)
                    .padding(.top, MortSpace.s1)
            }
        }
        .padding(.vertical, MortSpace.s8)
        .padding(.horizontal, MortSpace.s4)
        .frame(maxWidth: .infinity)
    }
}

/// Error state with an honest retry. Never shows internal error detail.
struct MortErrorState: View {
    var title: String = "Something went wrong"
    var message: String = "We couldn't load this just now. It's not something you did."
    var retryTitle: String = "Try again"
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: MortSpace.s4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(MortColor.warning)
            VStack(spacing: MortSpace.s2) {
                Text(title).mortH2().multilineTextAlignment(.center)
                Text(message)
                    .mortBody()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MortGhostButton(title: retryTitle, symbol: "arrow.clockwise", action: onRetry)
        }
        .padding(.vertical, MortSpace.s8)
        .padding(.horizontal, MortSpace.s4)
        .frame(maxWidth: .infinity)
    }
}

/// Offline banner. Saved records remain visible beneath it.
struct MortOfflineBanner: View {
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: MortSpace.s2) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MortColor.warning)
            VStack(alignment: .leading, spacing: 1) {
                Text("You're offline")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MortColor.textPrimary)
                Text("Showing records saved on this device.")
                    .mortMicro()
            }
            Spacer(minLength: MortSpace.s2)
            if let onRetry {
                Button("Retry") { onRetry() }
                    .font(MortFont.label())
                    .foregroundStyle(MortColor.silver3)
                    .frame(minHeight: MortMetric.minTouchTarget)
            }
        }
        .padding(.horizontal, MortSpace.s3)
        .padding(.vertical, MortSpace.s2)
        .background {
            RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                .fill(MortColor.warningDim)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                .strokeBorder(MortColor.warning.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A single skeleton bar. Shapes only — never fake text.
struct MortSkeletonBar: View {
    var width: CGFloat?
    var height: CGFloat = 12
    var radius: CGFloat = 6

    @Environment(\.mortReducedMotion) private var reducedMotion
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(MortColor.graphite3)
            .frame(width: width, height: height)
            .overlay {
                if !reducedMotion {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, MortColor.silver1.opacity(0.10), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmer ? 120 : -120)
                        .mask {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                        }
                }
            }
            .onAppear {
                guard !reducedMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Skeleton row used by list/timeline loading states.
struct MortSkeletonRow: View {
    var body: some View {
        HStack(spacing: MortSpace.s3) {
            Circle().fill(MortColor.graphite3).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: MortSpace.s2) {
                MortSkeletonBar(width: 150, height: 12)
                MortSkeletonBar(width: 96, height: 10)
            }
            Spacer(minLength: 0)
            MortSkeletonBar(width: 54, height: 12)
        }
        .padding(.vertical, MortSpace.s3)
        .accessibilityHidden(true)
    }
}

/// Full skeleton list with an accessible "loading" announcement.
struct MortSkeletonList: View {
    var rows: Int = 6

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { i in
                MortSkeletonRow()
                if i < rows - 1 { MortDivider() }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }
}

/// Pagination footer loader for infinite lists.
struct MortPaginationLoader: View {
    var body: some View {
        HStack(spacing: MortSpace.s2) {
            MortSpinner(size: 15)
            Text("Loading more…")
                .mortMicro()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MortSpace.s4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading more records")
    }
}

/// Restricted-state surface (guardian policy, safety restriction, role gate).
struct MortRestrictedState: View {
    let title: String
    let message: String
    var symbol: String = "lock.shield"

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                HStack(spacing: MortSpace.s2) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(MortColor.silver1)
                    Text(title)
                        .mortTitle()
                }
                Text(message)
                    .mortBody()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
