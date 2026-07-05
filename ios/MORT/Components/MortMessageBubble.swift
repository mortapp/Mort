//
//  MortMessageBubble.swift
//  MORT
//

import SwiftUI

struct MortMessageBubble: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(MortFont.body())
                    .foregroundStyle(isMine ? MortColor.productionBlack : MortColor.primaryText)
                    .padding(.horizontal, MortSpacing.md)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(.rect(cornerRadius: 18))
                Text(message.sentAt, style: .time)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(MortColor.darkSilver)
            }
            if !isMine { Spacer(minLength: 48) }
        }
    }

    private var bubbleBackground: AnyShapeStyle {
        if isMine {
            return AnyShapeStyle(
                LinearGradient(colors: [MortColor.lightRoseGold, MortColor.roseGold], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        return AnyShapeStyle(MortColor.surfaceElevated)
    }
}
