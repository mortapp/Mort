import Foundation

enum MortValidators {
    static func email(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = clean.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression)
        return range == nil ? "Enter a valid email." : nil
    }

    static func password(_ value: String, minimumLength: Int = 8) -> String? {
        value.count < minimumLength ? "Use at least \(minimumLength) characters." : nil
    }

    static func required(_ value: String, minimumLength: Int = 1, maximumLength: Int = 500) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count < minimumLength { return "Required." }
        if clean.count > maximumLength { return "Keep this under \(maximumLength) characters." }
        return nil
    }

    static func stateCode(_ value: String) -> String? {
        value.range(of: #"^[A-Za-z]{2}$"#, options: .regularExpression) == nil ? "Use a 2-letter state code." : nil
    }
}
