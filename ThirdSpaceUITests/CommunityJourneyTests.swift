import XCTest

/// Acceptance criteria 2–9 through the real UI, against the on-device synthetic backend.
@MainActor final class CommunityJourneyTests: JourneyTestCase {
    private func any(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func createAccount(_ username: String, in app: XCUIApplication) {
        select("Profile", in: app)
        let open = app.buttons["open-account"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        app.buttons["Create account"].firstMatch.tap()
        type("\(username)", into: "account-username", in: app)
        type("\(username)@test.example", into: "account-email", in: app)
        type("secret1", into: "account-password", in: app, secure: true)
        app.buttons["account-submit"].tap()
        XCTAssertTrue(any("signed-in-username", in: app).waitForExistence(timeout: 10), "Account was not created")
    }

    private func type(_ text: String, into identifier: String, in app: XCUIApplication, secure: Bool = false) {
        let field = secure ? app.secureTextFields[identifier] : any(identifier, in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing field \(identifier)")
        field.tap(); field.typeText(text)
    }

    private func switchTo(_ testAccount: String, in app: XCUIApplication) {
        select("Profile", in: app)
        let signOut = app.buttons["Sign out"]
        if signOut.waitForExistence(timeout: 3) { signOut.tap() }
        app.buttons["open-account"].tap()
        let account = app.buttons[testAccount]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        for _ in 0..<4 where !account.isHittable { app.swipeUp() }
        account.tap()
        XCTAssertTrue(any("signed-in-username", in: app).waitForExistence(timeout: 10))
    }

    private func openReadingRoom(in app: XCUIApplication) {
        select("Explore", in: app)
        let search = app.textFields["Search owned places"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        // The query persists between visits; clear it before typing.
        let existing = (search.value as? String) ?? ""
        if !existing.isEmpty && existing != "Search owned places" {
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        search.typeText("Reading\n")
        let open = app.buttons["Open SYNTHETIC — Reading Room"]
        reveal(open, in: app)
        open.tap()
        XCTAssertTrue(app.staticTexts["Hours unknown — check before visiting"].waitForExistence(timeout: 5))
    }

    private func back(_ app: XCUIApplication) { app.navigationBars.buttons.firstMatch.tap() }

    // Criteria 2 + 3
    func testSubmitPlaceModeratorApprovesAndSubmitterSeesDecision() {
        let app = launch(["--reset-local-data"])
        createAccount("tester_one", in: app)
        app.buttons["Add or contribute"].tap()
        any("submit-place-link", in: app).tap()
        type("Synthetic Test Nook", into: "submit-name", in: app)
        type("A quiet corner for testing.", into: "submit-description", in: app)
        type("123 Test Street", into: "submit-street", in: app)
        type("Testville", into: "submit-city", in: app)
        type("Testland", into: "submit-country", in: app)
        // Typed coordinates are the accessible alternative to dragging the map.
        let latitude = any("submit-latitude", in: app)
        for _ in 0..<4 where !latitude.isHittable { app.swipeUp() }
        type("34.05", into: "submit-latitude", in: app)
        type("-118.24", into: "submit-longitude", in: app)
        let submit = app.buttons["Submit for review"]
        for _ in 0..<4 where !submit.isHittable { app.swipeUp() }
        submit.tap()
        XCTAssertTrue(any("submission-pending", in: app).waitForExistence(timeout: 5), "No pending-review confirmation")
        capture(app, "Submission pending review")
        back(app)
        app.buttons["Close"].tap()

        select("Profile", in: app)
        let mine = any("submission-Synthetic Test Nook", in: app)
        reveal(mine, in: app)
        XCTAssertTrue(mine.label.contains("Pending review"), mine.label)

        switchTo("Use test moderator", in: app)
        any("moderation-queue", in: app).tap()
        let approve = app.buttons["Approve Synthetic Test Nook"]
        XCTAssertTrue(approve.waitForExistence(timeout: 5))
        capture(app, "Moderator queue")
        approve.tap()
        XCTAssertTrue(app.staticTexts["Nothing waiting."].waitForExistence(timeout: 5))
        back(app)

        app.buttons["Sign out"].tap()
        app.buttons["open-account"].tap()
        type("tester_one@test.example", into: "account-email", in: app)
        type("secret1", into: "account-password", in: app, secure: true)
        app.buttons["account-submit"].tap()
        let decided = any("submission-Synthetic Test Nook", in: app)
        reveal(decided, in: app)
        XCTAssertTrue(decided.label.contains("Approved"), decided.label)

        select("Explore", in: app)
        let search = app.textFields["Search owned places"]
        search.tap(); search.typeText("Test Nook\n")
        XCTAssertTrue(app.buttons["Open Synthetic Test Nook"].waitForExistence(timeout: 10), "Approved place is not public")
        capture(app, "Approved submission is public")
    }

    // Criteria 4–9
    func testRateReviewLikeFollowPersistAndReportReachesModerator() {
        let app = launch(["--reset-local-data"])
        createAccount("tester_two", in: app)
        openReadingRoom(in: app)

        let like = any("like-button", in: app)
        reveal(like, in: app)
        like.tap()
        XCTAssertTrue(app.buttons["Unlike"].waitForExistence(timeout: 5))
        any("rate-4", in: app).tap()
        let summary = any("rating-summary", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let rated = NSPredicate(format: "label CONTAINS %@", "3.5 · 2 ratings")
        expectation(for: rated, evaluatedWith: summary)
        waitForExpectations(timeout: 5)
        let review = any("review-text", in: app)
        reveal(review, in: app)
        review.tap(); review.typeText("SYNTHETIC test review: quiet tables")
        any("post-review", in: app).tap()
        XCTAssertTrue(app.staticTexts["SYNTHETIC test review: quiet tables"].waitForExistence(timeout: 5))

        back(app)
        openReadingRoom(in: app)
        let reopenedReview = app.staticTexts["SYNTHETIC test review: quiet tables"]
        reveal(reopenedReview, in: app)
        XCTAssertTrue(app.buttons["Unlike"].exists, "Like did not persist")
        XCTAssertTrue(any("rate-4", in: app).isSelected, "Rating did not persist")
        XCTAssertTrue(any("rating-summary", in: app).label.contains("3.5 · 2 ratings"))
        capture(app, "Rating, like and review after reopening")

        let author = any("review-author-SYNTHETIC_neighbor", in: app)
        reveal(author, in: app)
        author.tap()
        let follow = any("follow-button", in: app)
        XCTAssertTrue(follow.waitForExistence(timeout: 5))
        follow.tap()
        XCTAssertTrue(app.buttons["Unfollow SYNTHETIC_neighbor"].waitForExistence(timeout: 5))
        back(app)
        author.tap()
        XCTAssertTrue(app.buttons["Unfollow SYNTHETIC_neighbor"].waitForExistence(timeout: 5), "Follow did not persist")
        any("report-account", in: app).tap()
        app.buttons["send-report"].tap()
        XCTAssertTrue(any("report-confirmation", in: app).waitForExistence(timeout: 5))
        capture(app, "Report confirmation")
        app.buttons["Done"].tap()
        back(app)
        back(app)

        // Criterion 8: liking a study place recommends another study place first.
        select("Explore", in: app)
        let first = any("recommended-0", in: app)
        reveal(first, in: app)
        XCTAssertTrue(first.label.contains("परीक्षण"), "Expected the other synthetic study room first: \(first.label)")
        capture(app, "Recommended for you")

        switchTo("Use test moderator", in: app)
        any("moderation-queue", in: app).tap()
        XCTAssertTrue(any("report-profile", in: app).waitForExistence(timeout: 5), "Report not in moderator queue")
        capture(app, "Report in moderator queue")
    }
}
