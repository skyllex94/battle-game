import XCTest

final class DetailPreviewShot: XCTestCase {
    @MainActor
    func testDetailShot() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["CAMPAIGN"].waitForExistence(timeout: 10))
        app.buttons["CAMPAIGN"].tap()
        // First map node (page 0).
        let node = app.staticTexts["1. VERDANT LANDING"]
        XCTAssertTrue(node.waitForExistence(timeout: 10))
        node.tap()
        // Briefing diorama builds a runloop after push + bakes on frost only.
        sleep(4)
        let shot = app.screenshot()
        try shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/detail.png"))
    }
}
