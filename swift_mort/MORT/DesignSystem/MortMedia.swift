import SwiftUI

struct MortAvatar: View {
    let displayName: String
    var url: URL?
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image): image.resizable().scaledToFill()
                    case .failure: fallback
                    default: ProgressView().tint(MortColors.neon)
                    }
                }
            } else { fallback }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(MortColors.line))
        .accessibilityLabel("Profile picture for \(displayName)")
    }

    private var fallback: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(MortColors.background)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MortColors.neon)
    }

    private var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let value = parts.compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "M" : value.uppercased()
    }
}

struct MortAsyncImage: View {
    let url: URL?
    var height: CGFloat = 190

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image): image.resizable().scaledToFill()
            case .failure:
                ZStack { MortColors.cardAlternate; Image(systemName: "photo").foregroundStyle(MortColors.textMuted) }
            default: ZStack { MortColors.cardAlternate; ProgressView().tint(MortColors.neon) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
    }
}
