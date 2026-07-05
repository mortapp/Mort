//
//  MortAvatar.swift
//  MORT
//

import SwiftUI

struct MortAvatar: View {
    let name: String
    var urlString: String? = nil
    var size: CGFloat = 44

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [MortColor.roseGold, MortColor.warmRose],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let urlString, let url = URL(string: urlString), urlString.hasPrefix("http") {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(initials).font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                        .foregroundStyle(MortColor.productionBlack)
                }
                .clipShape(Circle())
            } else {
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(MortColor.productionBlack)
            }
        }
        .frame(width: size, height: size)
    }
}
