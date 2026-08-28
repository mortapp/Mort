import CoreGraphics
import XCTest
@testable import MORT

final class AvatarCropGeometryTests: XCTestCase {
    func testWideImageFillsViewportAndClampsHorizontalMovement() {
        let size = AvatarCropGeometry.displaySize(
            imageSize: CGSize(width: 800, height: 400),
            viewport: 300,
            zoom: 1
        )
        XCTAssertEqual(size.width, 600, accuracy: 0.001)
        XCTAssertEqual(size.height, 300, accuracy: 0.001)

        let offset = AvatarCropGeometry.clampedOffset(
            CGSize(width: 500, height: 80),
            imageSize: CGSize(width: 800, height: 400),
            viewport: 300,
            zoom: 1
        )
        XCTAssertEqual(offset.width, 150, accuracy: 0.001)
        XCTAssertEqual(offset.height, 0, accuracy: 0.001)
    }

    func testTallImageClampsVerticalMovement() {
        let offset = AvatarCropGeometry.clampedOffset(
            CGSize(width: -20, height: -900),
            imageSize: CGSize(width: 400, height: 1_000),
            viewport: 320,
            zoom: 1
        )
        XCTAssertEqual(offset.width, 0, accuracy: 0.001)
        XCTAssertEqual(offset.height, -240, accuracy: 0.001)
    }

    func testDrawRectMatchesCenteredWideCrop() {
        let rect = AvatarCropGeometry.drawRect(
            imageSize: CGSize(width: 800, height: 400),
            viewport: 300,
            outputEdge: 600,
            zoom: 1,
            offset: .zero
        )
        XCTAssertEqual(rect.origin.x, -300, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(rect.width, 1_200, accuracy: 0.001)
        XCTAssertEqual(rect.height, 600, accuracy: 0.001)
    }
}
