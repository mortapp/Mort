import SwiftUI

struct MortCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(MortSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MortColors.card)
            .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
            .overlay(RoundedRectangle(cornerRadius: MortRadius.medium).stroke(MortColors.line.opacity(0.75)))
    }
}

struct MortBadge: View {
    let text: String
    var tint: Color = MortColors.safetyBlue

    var body: some View {
        Text(text.uppercased())
            .font(MortTypography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, MortSpacing.xs)
            .padding(.vertical, MortSpacing.xxs)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: MortRadius.small))
    }
}

struct MortSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.xxs) {
            Text(title).font(MortTypography.section).foregroundStyle(MortColors.text)
            if let subtitle { Text(subtitle).font(MortTypography.caption).foregroundStyle(MortColors.textMuted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MortEmptyState: View {
    let title: String
    let message: String
    var systemImage = "tray"

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .foregroundStyle(MortColors.text)
    }
}

struct MortErrorState: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: MortSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle).foregroundStyle(MortColors.warning)
            Text("Could not load this").font(MortTypography.section)
            Text(message).multilineTextAlignment(.center).foregroundStyle(MortColors.textMuted)
            if let retry { MortSecondaryButton(title: "Try again", icon: "arrow.clockwise", action: retry) }
        }
        .padding(MortSpacing.xl)
    }
}

struct MortLoadingState: View {
    var label = "Loading MORT"

    var body: some View {
        VStack(spacing: MortSpacing.md) {
            ProgressView().tint(MortColors.neon).controlSize(.large)
            Text(label).font(MortTypography.label).foregroundStyle(MortColors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MortSkeleton: View {
    var height: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: MortRadius.small)
            .fill(MortColors.cardAlternate)
            .frame(height: height)
            .redacted(reason: .placeholder)
    }
}

struct MortAlertBanner: View {
    let title: String
    let message: String
    var tint = MortColors.warning
    var icon = "exclamationmark.circle.fill"

    var body: some View {
        HStack(alignment: .top, spacing: MortSpacing.sm) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                Text(title).font(MortTypography.label)
                Text(message).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            }
        }
        .padding(MortSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
    }
}

struct MortSafetyBanner: View {
    let message: String

    var body: some View {
        MortAlertBanner(title: "Safety first", message: message, tint: MortColors.safetyBlue, icon: "shield.fill")
    }
}

struct MortBottomSheet<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView { content.padding(MortSpacing.md) }
                .background(MortColors.background)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

extension View {
    func mortScreen() -> some View {
        self
            .foregroundStyle(MortColors.text)
            .background(MortColors.background.ignoresSafeArea())
            .tint(MortColors.neon)
    }

    func mortConfirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        confirmTitle: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button(confirmTitle, role: role, action: action)
            Button("Cancel", role: .cancel) {}
        }
    }
}
