//
//  MortCard.swift
//  MORT
//

import SwiftUI

struct MortCard<Content: View>: View {
    var padding: CGFloat = MortSpacing.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mortSurface()
    }
}
