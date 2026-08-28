import XCTest

final class MORTLaunchTests: XCTestCase {
    func testApplicationLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
