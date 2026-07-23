import Foundation

enum DateOfBirthRules {
    static let teenMinimumAge = 13
    static let teenMaximumAge = 17
    static let adultMinimumAge = 18
    private static let utc = TimeZone(secondsFromGMT: 0) ?? TimeZone.current

    static func formattedInput(_ input: String) -> String {
        if input.count >= 10,
           input.indices.contains(input.index(input.startIndex, offsetBy: 4)),
           input[input.index(input.startIndex, offsetBy: 4)] == "-" {
            let parts = input.prefix(10).split(separator: "-")
            if parts.count == 3 { return "\(parts[1])/\(parts[2])/\(parts[0])" }
        }
        let digits = input.filter(\.isNumber).prefix(8)
        var result = ""
        for (index, digit) in digits.enumerated() {
            result.append(digit)
            if index == 1 || index == 3 { result.append("/") }
        }
        return result
    }

    static func parse(_ value: String, today: Date = Date(), calendar: Calendar = .current) throws -> Date {
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 2,
              parts[1].count == 2,
              parts[2].count == 4,
              let month = Int(parts[0]),
              let day = Int(parts[1]),
              let year = Int(parts[2])
        else { throw MortError.invalidInput("Use MM/DD/YYYY.") }

        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = utc
        var components = DateComponents()
        components.calendar = gregorian
        components.timeZone = gregorian.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = gregorian.date(from: components),
              gregorian.component(.year, from: date) == year,
              gregorian.component(.month, from: date) == month,
              gregorian.component(.day, from: date) == day
        else { throw MortError.invalidInput("Enter a real calendar date.") }

        let todayParts = calendar.dateComponents([.year, .month, .day], from: today)
        let isFuture = year > (todayParts.year ?? year) ||
            (year == todayParts.year && month > (todayParts.month ?? month)) ||
            (year == todayParts.year && month == todayParts.month && day > (todayParts.day ?? day))
        guard !isFuture else { throw MortError.invalidInput("Date of birth cannot be in the future.") }
        guard age(on: date, today: today, calendar: calendar) <= 120 else {
            throw MortError.invalidInput("Enter a real date of birth.")
        }
        return date
    }

    static func age(on date: Date, today: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> Int {
        var birthCalendar = Calendar(identifier: .gregorian)
        birthCalendar.timeZone = utc
        let birth = birthCalendar.dateComponents([.year, .month, .day], from: date)
        let current = calendar.dateComponents([.year, .month, .day], from: today)
        guard let birthYear = birth.year, let birthMonth = birth.month, let birthDay = birth.day,
              let currentYear = current.year, let currentMonth = current.month, let currentDay = current.day
        else { return 0 }
        var result = currentYear - birthYear
        if currentMonth < birthMonth || (currentMonth == birthMonth && currentDay < birthDay) { result -= 1 }
        return result
    }

    static func validateRole(_ role: UserRole, date: Date, today: Date = Date()) throws {
        let value = age(on: date, today: today)
        switch role {
        case .teen where !(teenMinimumAge...teenMaximumAge).contains(value):
            throw MortError.invalidInput("Teens must be ages 13-17.")
        case .adult, .guardian where value < adultMinimumAge:
            throw MortError.invalidInput("Adults and guardians must be 18 or older.")
        case .admin:
            throw MortError.invalidInput("Admin access cannot be selected during onboarding.")
        default:
            return
        }
    }

    static func isoDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
