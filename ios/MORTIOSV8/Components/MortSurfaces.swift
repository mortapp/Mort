//
//  MortSurfaces.swift
//  MORT iOS V8 — Components
//
//  Black-glass / smoked-graphite surfaces with hairline borders. These are the
//  only card backgrounds in the app: no glassmorphism everywhere, no gradients
//  as decoration.
//

import SwiftUI

/// The standard MORT card: smoked black glass with a hairline edge.
struct MortCard<Content: View>: View {
    var padding: CGFloat = MortSpace.s4
    var radius: CGFloat = MortRadius.lg
    var tint: Color = MortColor.cardBg2
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint)
            }
            .mortHairlineBorder(radius: radius)
    }
}

/// A quieter inset surface used inside cards (nested rows, breakdown blocks).
struct MortInsetSurface<Content: View>: View {
    var padding: CGFloat = MortSpace.s3
    var radius: CGFloat = MortRadius.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(MortColor.graphite2.opacity(0.7))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(MortColor.hairline, lineWidth: 1)
            }
    }
}

/// Section heading with an uppercase tracked eyebrow and optional trailing
/// accessory.
struct MortSectionHeader<Accessory: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: MortSpace.s1) {
                Text(title.uppercased())
                    .mortEyebrow()
                if let subtitle {
                    Text(subtitle)
                        .mortMicro()
                }
            }
            Spacer(minLength: MortSpace.s3)
            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension MortSectionHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A hairline divider.
struct MortDivider: View {
    var body: some View {
        Rectangle()
            .fill(MortColor.hairline2)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// The app's screen scaffold: atmosphere behind content, safe-area aware, with
/// an optional sticky bottom bar. Every screen uses this — never a bare
/// SwiftUI background.
struct MortScreen<Content: View, Bottom: View>: View {
    var title: String?
    var subtitle: String?
    /// Atmosphere intensity — quieter behind dense reading surfaces.
        var atmosphereIntensity: Double = 1.0
    var showsForegroundMeteors: Bool = false
    var scrolls: Bool = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        ZStack {
            MortAtmosphere(intensity: atmosphereIntensity)

            Group {
                if scrolls {
                    ScrollView {
                        inner
                            .padding(.bottom, MortSpace.s8)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    inner
                }
            }

            if showsForegroundMeteors {
                MortAtmosphereForeground()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottom()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var inner: some View {
        VStack(alignment: .leading, spacing: MortSpace.s5) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: MortSpace.s2) {
                    if let title {
                        Text(title)
                            .mortH1()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .mortBody()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            content()
        }
        .mortScreenPadding()
        .padding(.top, MortSpace.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension MortScreen where Bottom == EmptyView {
    init(
        title: String? = nil,
        subtitle: String? = nil,
        atmosphereIntensity: Double = 1.0,
        showsForegroundMeteors: Bool = false,
        scrolls: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            atmosphereIntensity: atmosphereIntensity,
            showsForegroundMeteors: showsForegroundMeteors,
            scrolls: scrolls,
            content: content,
            bottom: { EmptyView() }
        )
    }
}

/// Sticky bottom action bar with a blurred graphite base so content scrolls
/// under it legibly.
struct MortBottomBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: MortSpace.s2) {
            content()
        }
        .padding(.horizontal, MortSpace.screen)
        .padding(.top, MortSpace.s3)
        .padding(.bottom, MortSpace.s2)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(MortColor.ink2.opacity(0.82))
                VStack {
                    Rectangle().fill(MortColor.hairline2).frame(height: 1)
                    Spacer()
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
