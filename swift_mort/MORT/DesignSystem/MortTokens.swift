import SwiftUI

enum MortColors {
    static let background = Color(hex: 0x050607)
    static let elevated = Color(hex: 0x0D1012)
    static let card = Color(hex: 0x12161A)
    static let cardAlternate = Color(hex: 0x191F24)
    static let line = Color(hex: 0x273038)
    static let text = Color(hex: 0xF3F7F2)
    static let textMuted = Color(hex: 0x9AA6A0)
    static let textSoft = Color(hex: 0xC7D0CA)
    static let neon = Color(hex: 0x7CFF6B)
    static let neonDeep = Color(hex: 0x0B3D18)
    static let safetyBlue = Color(hex: 0x4DB8FF)
    static let warning = Color(hex: 0xFFB34D)
    static let danger = Color(hex: 0xFF5A6A)
    static let premium = Color(hex: 0x9E7CFF)
}

enum MortSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
    static let maxContentWidth: CGFloat = 760
}

enum MortRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
}

enum MortTypography {
    static let hero = Font.system(size: 38, weight: .black, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let section = Font.system(size: 20, weight: .bold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular)
    static let label = Font.system(size: 14, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .medium)
}

enum MortAnimation {
    static let quick = Animation.easeOut(duration: 0.16)
    static let standard = Animation.easeInOut(duration: 0.24)
}

enum MortShadows {
    static let color = Color.black.opacity(0.28)
    static let radius: CGFloat = 12
    static let y: CGFloat = 6
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
