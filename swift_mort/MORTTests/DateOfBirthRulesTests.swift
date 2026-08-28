import XCTest
@testable import MORT

final class DateOfBirthRulesTests: XCTestCase {
    func testAutomaticSlashInsertion() {
        XCTAssertEqual(DateOfBirthRules.formattedInput("06"), "06/")
        XCTAssertEqual(DateOfBirthRules.formattedInput("0629"), "06/29/")
        XCTAssertEqual(DateOfBirthRules.formattedInput("06292011"), "06/29/2011")
        XCTAssertEqual(DateOfBirthRules.formattedInput("2011-06-29"), "06/29/2011")
    }

    func testLeapYearAndImpossibleDates() throws {
        let today = try fixedDate(2026, 7, 14)
        XCTAssertNoThrow(try DateOfBirthRules.parse("02/29/2012", today: today, calendar: utcCalendar))
        XCTAssertThrowsError(try DateOfBirthRules.parse("02/29/2011", today: today, calendar: utcCalendar))
        XCTAssertThrowsError(try DateOfBirthRules.parse("04/31/2011", today: today, calendar: utcCalendar))
    }

    func testDateOnlyRoundTripDoesNotShiftTimezone() throws {
        var indianapolis = Calendar(identifier: .gregorian)
        indianapolis.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Indiana/Indianapolis"))
        let today = try fixedDate(2026, 7, 14)
        let value = try DateOfBirthRules.parse("06/29/2011", today: today, calendar: indianapolis)
        XCTAssertEqual(DateOfBirthRules.isoDate(value), "2011-06-29")
    }

    func testAgeChangesOnBirthday() throws {
        let birth = try DateOfBirthRules.parse("07/14/2011", today: fixedDate(2026, 7, 14), calendar: utcCalendar)
        XCTAssertEqual(DateOfBirthRules.age(on: birth, today: try fixedDate(2026, 7, 13), calendar: utcCalendar), 14)
        XCTAssertEqual(DateOfBirthRules.age(on: birth, today: try fixedDate(2026, 7, 14), calendar: utcCalendar), 15)
    }

    func testRoleAgeBoundaries() throws {
        let today = try fixedDate(2026, 7, 14)
        let thirteen = try DateOfBirthRules.parse("07/14/2013", today: today, calendar: utcCalendar)
        let seventeen = try DateOfBirthRules.parse("07/14/2009", today: today, calendar: utcCalendar)
        let eighteen = try DateOfBirthRules.parse("07/14/2008", today: today, calendar: utcCalendar)
        XCTAssertNoThrow(try DateOfBirthRules.validateRole(.teen, date: thirteen, today: today))
        XCTAssertNoThrow(try DateOfBirthRules.validateRole(.teen, date: seventeen, today: today))
        XCTAssertThrowsError(try DateOfBirthRules.validateRole(.teen, date: eighteen, today: today))
        XCTAssertNoThrow(try DateOfBirthRules.validateRole(.adult, date: eighteen, today: today))
        XCTAssertNoThrow(try DateOfBirthRules.validateRole(.guardian, date: eighteen, today: today))
        XCTAssertThrowsError(try DateOfBirthRules.validateRole(.admin, date: eighteen, today: today))
    }

    func testFutureDOBIsRejected() throws {
        XCTAssertThrowsError(try DateOfBirthRules.parse("07/15/2026", today: fixedDate(2026, 7, 14), calendar: utcCalendar))
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func fixedDate(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = utcCalendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return try XCTUnwrap(utcCalendar.date(from: components))
    }
}
