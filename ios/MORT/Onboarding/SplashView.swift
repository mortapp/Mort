//
//  SplashView.swift
//  MORT
//

import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            MortBackground()
            VStack(spacing: MortSpacing.sm) {
                Text("MORT")
                    .font(MortFont.wordmark())
                    .tracking(6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [MortColor.offWhite, MortColor.lightRoseGold, MortColor.roseGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("GET IN MOTION")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(MortColor.secondaryText)

                Rectangle()
                    .fill(MortColor.roseGold)
                    .frame(width: appeared ? 64 : 0, height: 2)
                    .padding(.top, MortSpacing.md)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.94)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                onFinish()
            }
        }
    }
}
