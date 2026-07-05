//
//  MortButton.swift
//  MORT
//

import SwiftUI

enum MortButtonStyleKind {
    case primary
    case secondary
    case ghost
    case destructive
}

struct MortButton: View {
    let title: String
    var systemImage: String? = nil
    var kind: MortButtonStyleKind = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: MortSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage)
                    }
                    Text(title)
                        .font(MortFont.headline())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(.rect(cornerRadius: MortRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: MortRadius.md)
                    .stroke(strokeColor, lineWidth: kind == .ghost ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1)
        .opacity(isDisabled || isLoading ? 0.55 : 1)
        .disabled(isDisabled || isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }

    private var foreground: Color {
        switch kind {
        case .primary: return MortColor.productionBlack
        case .secondary: return MortColor.primaryText
        case .ghost: return MortColor.primaryText
        case .destructive: return MortColor.white
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [MortColor.lightRoseGold, MortColor.roseGold],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary: return AnyShapeStyle(MortColor.surfaceElevated)
        case .ghost: return AnyShapeStyle(Color.clear)
        case .destructive: return AnyShapeStyle(MortColor.danger)
        }
    }

    private var strokeColor: Color {
        kind == .ghost ? MortColor.stroke : .clear
    }
}
