import Foundation

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
}

extension Int {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = isMultiple(of: 100) ? 0 : 2
        return formatter.string(from: NSNumber(value: Double(self) / 100)) ?? "$\(Double(self) / 100)"
    }
}

extension Date {
    var iso8601String: String { ISO8601DateFormatter().string(from: self) }
}

enum DateFormatting {
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func displayDateTime(_ value: String?) -> String {
        guard let value,
              let date = ISO8601DateFormatter().date(from: value)
        else { return "Not scheduled" }
        return displayFormatter.string(from: date)
    }
}
