//
//  SafetyScanner.swift
//  MORT
//
//  Local content safety scanner. Detects contact info, off-platform handles,
//  payment tags, and unsafe content. Pure logic, no UI, nonisolated for reuse.
//

import Foundation

/// The friendly warning shown whenever unsafe content is detected.
let mortSafetyWarning = "Keep contact and unsafe details off MORT for safety."

nonisolated enum SafetyScanner {

    /// Scan free text for unsafe content and return a structured result.
    static func scan(_ raw: String) -> SafetyScanResult {
        let text = raw
        let lower = raw.lowercased()
        var matches: [SafetyMatch] = []

        func add(_ category: String, _ snippet: String) {
            matches.append(SafetyMatch(category: category, snippet: snippet))
        }

        // MARK: Contact info (regex based)
        if let m = firstMatch(in: text, pattern: #"(?:(?:\+?\d[\s.-]?){7,}\d)"#) {
            add("Phone number", m)
        }
        if let m = firstMatch(in: text, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, caseInsensitive: true) {
            add("Email address", m)
        }
        if let m = firstMatch(in: text, pattern: #"(?:https?://|www\.)\S+"#, caseInsensitive: true) {
            add("Link / URL", m)
        }
        if let m = firstMatch(in: text, pattern: #"\d{1,5}\s+\w+(?:\s\w+)*\s+(?:street|st|avenue|ave|road|rd|blvd|lane|ln|drive|dr|court|ct|way)\b"#, caseInsensitive: true) {
            add("Street address", m)
        }
        if let m = firstMatch(in: text, pattern: #"\$[A-Za-z][A-Za-z0-9_]{2,}"#) {
            add("Cash App tag", m)
        }
        if let m = firstMatch(in: text, pattern: #"@[A-Za-z0-9_.]{2,}"#) {
            add("Social handle", m)
        }

        // MARK: Keyword groups
        let groups: [(category: String, terms: [String])] = [
            ("Payment app", ["venmo", "zelle", "paypal", "cashapp", "cash app", "apple pay", "google pay"]),
            ("Social media", ["snapchat", "snap me", "snapme", "instagram", "insta", "tiktok", "discord", "telegram", "whatsapp", "kik", "facebook", "messenger", "twitter", "x.com", "onlyfans"]),
            ("Off-platform contact", ["text me", "call me", "dm me", "hit me up off", "off the app", "off platform", "off-platform", "message me on"]),
            ("Adult / sexual content", ["nude", "nudes", "sext", "sexual", "porn", "onlyfans", "hookup", "hook up"]),
            ("Drugs", ["weed", "marijuana", "cocaine", "molly", "lsd", "meth", "plug", "drugs", "pills", "xan", "percs"]),
            ("Alcohol", ["alcohol", "beer", "liquor", "vodka", "whiskey", "buy me booze"]),
            ("Tobacco / vape", ["cigarette", "tobacco", "vape", "vapes", "juul", "nicotine"]),
            ("Weapons", ["gun", "guns", "firearm", "pistol", "knife for", "ammo", "weapon"]),
            ("Gambling", ["gambling", "betting", "casino", "poker for money", "sports bet"]),
            ("Crypto / scam", ["crypto", "bitcoin", "ethereum", "nft", "investment opportunity", "double your money", "guaranteed returns", "forex", "wire transfer"]),
            ("Dangerous tools", ["chainsaw", "blowtorch", "power saw alone", "explosive", "fireworks"]),
            ("Unsafe meetup", ["come alone", "meet alone", "my place late", "late at night alone", "abandoned", "no one around", "secret meetup", "don't tell anyone", "dont tell anyone"]),
            ("Harassment / threats", ["i'll hurt you", "ill hurt you", "kill you", "beat you up", "threat", "shut up or"]),
            ("Hate speech", ["hate speech"]),
            ("Spam / scam", ["free money", "click this link", "act now", "limited offer", "you won", "prince", "lottery"]),
        ]

        for group in groups {
            for term in group.terms where lower.contains(term) {
                add(group.category, term)
                break
            }
        }

        // MARK: Decide severity
        let blockingCategories: Set<String> = [
            "Adult / sexual content", "Drugs", "Weapons", "Crypto / scam",
            "Harassment / threats", "Hate speech", "Unsafe meetup",
        ]
        let hasBlock = matches.contains { blockingCategories.contains($0.category) }

        if matches.isEmpty {
            return .safe
        }
        let severity: SafetySeverity = hasBlock ? .block : .warn
        return SafetyScanResult(
            severity: severity,
            matches: matches,
            message: mortSafetyWarning
        )
    }

    /// Late-night / unsafe scheduling check used when posting jobs.
    static func scanSchedule(_ date: Date?) -> SafetyScanResult {
        guard let date else { return .safe }
        let hour = Calendar.current.component(.hour, from: date)
        if hour >= 21 || hour < 6 {
            return SafetyScanResult(
                severity: .warn,
                matches: [SafetyMatch(category: "Late-night job", snippet: "Scheduled outside safe hours")],
                message: "This time is late. Teens should only take jobs during safe daytime hours."
            )
        }
        return .safe
    }

    private static func firstMatch(in text: String, pattern: String, caseInsensitive: Bool = false) -> String? {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }
}
