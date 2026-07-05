//
//  MortStateViews.swift
//  MORT
//
//  Empty, loading, and error states.
//

import SwiftUI

struct MortEmptyState: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MortSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(MortColor.roseGold.opacity(0.8))
            Text(title)
                .font(MortFont.title2())
                .foregroundStyle(MortColor.primaryText)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(MortFont.callout())
                    .foregroundStyle(MortColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                MortButton(title: actionTitle, kind: .secondary, action: action)
                    .frame(maxWidth: 240)
                    .padding(.top, MortSpacing.xs)
            }
        }
        .padding(MortSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

struct MortLoadingView: View {
    var label: String = "Loading…"
    var body: some View {
        VStack(spacing: MortSpacing.sm) {
            ProgressView()
                .tint(MortColor.roseGold)
            Text(label)
                .font(MortFont.caption())
                .foregroundStyle(MortColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MortErrorView: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MortSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(MortColor.danger)
            Text("Something went wrong")
                .font(MortFont.title2())
                .foregroundStyle(MortColor.primaryText)
            Text(message)
                .font(MortFont.callout())
                .foregroundStyle(MortColor.secondaryText)
                .multilineTextAlignment(.center)
            if let retry {
                MortButton(title: "Try again", kind: .secondary, action: retry)
                    .frame(maxWidth: 200)
            }
        }
        .padding(MortSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}
