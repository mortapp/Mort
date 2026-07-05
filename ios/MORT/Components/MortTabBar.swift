//
//  MortTabBar.swift
//  MORT
//
//  Custom dark tab bar used by all role dashboards.
//

import SwiftUI

struct MortTabItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let systemImage: String
}

struct MortTabBar: View {
    let items: [MortTabItem]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = item.id
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 19, weight: .semibold))
                            .symbolVariant(selection == item.id ? .fill : .none)
                        Text(item.title)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selection == item.id ? MortColor.roseGold : MortColor.darkSilver)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, MortSpacing.xs)
        .background(
            MortColor.surface
                .overlay(Rectangle().fill(MortColor.stroke).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
