import XCTest

final class SwiftPagerKitDemoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPagerSmokeFlow() throws {
        let app = makeApp()
        app.launch()

        openFirstGalleryCell(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["demoPager"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["pageWormIndicator"].exists)

        swipeToNextPage(in: app)
        waitForPageIndicator(prefix: "Photo 2 of", in: app)

        app.buttons["jumpAhead"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["positionCounter"].waitForExistence(timeout: 2))
        waitForPageIndicator(prefix: "Photo 9 of", in: app)

        app.buttons["insertPage"].tap()
        waitForLastEvent(prefix: "append count=", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["itemCounter"].exists)

        XCTAssertTrue(app.buttons["closeGalleryPager"].waitForExistence(timeout: 5))
        app.buttons["closeGalleryPager"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["galleryGrid"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPagerSwipeGestureChangesPage() throws {
        let app = makeApp()
        app.launch()

        openFirstGalleryCell(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["demoPager"].waitForExistence(timeout: 10))

        let firstPage = app.descendants(matching: .any)["demoPage-0"]
        XCTAssertTrue(firstPage.waitForExistence(timeout: 5))
        XCTAssertTrue(firstPage.isHittable)

        swipeToNextPage(in: app)
        waitForPageIndicator(prefix: "Photo 2 of", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["demoPage-1"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGalleryDiagnosticsReportsLoadMoreAndRemoveCounts() throws {
        let app = makeApp()
        app.launch()

        openFirstGalleryCell(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["demoPager"].waitForExistence(timeout: 10))
        waitForElementText(identifier: "itemCounter", text: "18", in: app)

        app.buttons["insertPage"].tap()
        waitForLastEvent(prefix: "append count=27", in: app)
        waitForElementText(identifier: "itemCounter", text: "27", in: app)

        app.buttons["removePage"].tap()
        waitForLastEvent(prefix: "remove image=", in: app)
        waitForElementText(identifier: "itemCounter", text: "26", in: app)
    }

    @MainActor
    func testReelsTabShowsVerticalPager() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.buttons["demoTab-Reels"].waitForExistence(timeout: 5))
        app.buttons["demoTab-Reels"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["reelsPager"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["reelPage-0"].waitForExistence(timeout: 5))
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SWIFTPAGERKIT_DEMO_SHOW_DIAGNOSTICS"] = "1"
        app.launchEnvironment["SWIFTPAGERKIT_DEMO_DISABLE_GRID_AUTOPREFETCH"] = "1"
        return app
    }

    private func waitForLastEvent(prefix: String, in app: XCUIApplication) {
        let lastEvent = app.descendants(matching: .any)["lastEvent"]
        XCTAssertTrue(lastEvent.waitForExistence(timeout: 5))

        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        expectation(for: predicate, evaluatedWith: lastEvent)
        waitForExpectations(timeout: 5)
    }

    private func waitForPageIndicator(prefix: String, in app: XCUIApplication) {
        let pageIndicator = app.descendants(matching: .any)["pageWormIndicator"]
        XCTAssertTrue(pageIndicator.waitForExistence(timeout: 5))

        let predicate = NSPredicate(format: "value BEGINSWITH %@", prefix)
        expectation(for: predicate, evaluatedWith: pageIndicator)
        waitForExpectations(timeout: 5)
    }

    private func waitForElementText(identifier: String, text: String, in app: XCUIApplication) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5))

        let predicate = NSPredicate(format: "label == %@ OR value == %@", text, text)
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    private func openFirstGalleryCell(in app: XCUIApplication) {
        let firstCell = app.descendants(matching: .any)["galleryGridCell-0"]
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86)).tap()
    }

    private func swipeToNextPage(in app: XCUIApplication) {
        let pager = app.descendants(matching: .any)["demoPager"]
        XCTAssertTrue(pager.waitForExistence(timeout: 5))

        let start = pager.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.46))
        let end = pager.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.46))
        start.press(forDuration: 0.03, thenDragTo: end)
    }
}
