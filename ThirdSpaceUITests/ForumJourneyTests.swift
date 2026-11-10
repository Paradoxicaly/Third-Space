import XCTest

/// The Community tab as a forum: read threads without an account, open one, start a thread and answer,
/// all on the on-device synthetic backend.
@MainActor final class ForumJourneyTests: JourneyTestCase {
    private func any(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func type(_ text: String, into identifier: String, in app: XCUIApplication, secure: Bool = false) {
        let field = secure ? app.secureTextFields[identifier] : any(identifier, in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing field \(identifier)")
        field.tap(); field.typeText(text)
    }

    private func createAccount(_ username: String, in app: XCUIApplication) {
        select("Profile", in: app)
        let open = app.buttons["open-account"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        app.buttons["Create account"].firstMatch.tap()
        type(username, into: "account-username", in: app)
        type("\(username)@test.example", into: "account-email", in: app)
        type("secret1", into: "account-password", in: app, secure: true)
        app.buttons["account-submit"].tap()
        XCTAssertTrue(any("signed-in-username", in: app).waitForExistence(timeout: 10), "Account was not created")
    }

    /// Thread rows combine their text into one accessibility label, so match on contents.
    private func row(containing parts: String..., in app: XCUIApplication) -> XCUIElement {
        let predicates = parts.map { NSPredicate(format: "label CONTAINS %@", $0) }
        return app.buttons.matching(NSCompoundPredicate(andPredicateWithSubpredicates: predicates)).firstMatch
    }

    private let seededQuestion = "SYNTHETIC question: is it OK to stay a few hours?"

    func testReadThreadsAsGuestThenStartAThreadAndAnswer() {
        let app = launch(["--reset-local-data"])
        select("Community", in: app)
        let question = row(containing: seededQuestion, in: app)
        XCTAssertTrue(question.waitForExistence(timeout: 10), "Seeded thread should show without an account")
        XCTAssertTrue(row(containing: "SYNTHETIC visit note", in: app).exists)
        capture(app, "Community forum feed")

        question.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "SYNTHETIC answer")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign in to answer"].exists, "Guests read threads and are invited to sign in to answer")
        capture(app, "Thread with an answer")
        app.navigationBars.buttons.firstMatch.tap()

        createAccount("forum_member", in: app)
        select("Community", in: app)
        let start = app.buttons["start-thread"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        type("Reading", into: "thread-place-search", in: app)
        let choose = app.buttons["Choose SYNTHETIC — Reading Room"]
        XCTAssertTrue(choose.waitForExistence(timeout: 10))
        choose.tap()
        XCTAssertTrue(any("thread-chosen-place", in: app).waitForExistence(timeout: 5))
        type("SYNTHETIC Where are the quiet tables?", into: "thread-title", in: app)
        type("Invented test thread for the forum journey.", into: "thread-body", in: app)
        capture(app, "Starting a thread")
        app.buttons["thread-post"].tap()

        let mine = row(containing: "SYNTHETIC Where are the quiet tables?", "Waiting for review", in: app)
        XCTAssertTrue(mine.waitForExistence(timeout: 10), "Own new thread should appear, marked as waiting for review")
        capture(app, "Own thread waiting for review")

        row(containing: seededQuestion, in: app).tap()
        let answer = any("thread-answer-text", in: app)
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        reveal(answer, in: app)
        answer.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Answer field did not take focus")
        answer.typeText("SYNTHETIC answer from the forum journey.")
        app.buttons["keyboard-done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "Done should close the keyboard")
        let submit = app.buttons["thread-answer-submit"]
        reveal(submit, in: app)
        submit.tap()
        XCTAssertTrue(any("thread-answer-sent", in: app).waitForExistence(timeout: 5))
        capture(app, "Answer sent for review")
    }
}
