//
//  AssessmentFlowUITests.swift
//  PaddleUpUITests
//
//  Regression: tapping START ASSESSMENT presented the practice flow in a
//  full-screen cover that had no PracticeRouter in its environment, which
//  crashed the app ("No Observable object of type PracticeRouter found").
//

import XCTest

final class AssessmentFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStartAssessmentOpensCameraSetupWithoutCrashing() throws {
        let app = XCUIApplication()
        app.launch()

        completeOnboarding(app)

        let practiceTab = app.tabBars.buttons["Practice"]
        XCTAssertTrue(practiceTab.waitForExistence(timeout: 15), "Main tabs never appeared")
        practiceTab.tap()

        let startAssessment = app.buttons["START ASSESSMENT"]
        XCTAssertTrue(startAssessment.waitForExistence(timeout: 10), "START ASSESSMENT not found")
        startAssessment.tap()

        // Source picker: both inputs must be offered.
        let recordLive = app.buttons["Record Live"]
        XCTAssertTrue(recordLive.waitForExistence(timeout: 10), "Record Live option missing")
        XCTAssertTrue(app.buttons["Upload Video"].exists, "Upload Video option missing")
        recordLive.tap()

        allowCameraIfAsked()

        // Any of the camera flow's states proves the cover presented and the
        // app survived reading PracticeRouter.
        let setupTitle = app.staticTexts["Camera Setup"]
        let noCamera = app.staticTexts["No camera available"]
        let denied = app.staticTexts["Camera access needed"]
        let deadline = Date().addingTimeInterval(20)
        var reached = false
        while Date() < deadline {
            if setupTitle.exists || noCamera.exists || denied.exists { reached = true; break }
            XCTAssertEqual(app.state, .runningForeground, "App exited after START ASSESSMENT")
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertTrue(reached, "Camera setup flow never appeared")
        XCTAssertEqual(app.state, .runningForeground)

        if setupTitle.exists {
            // Setup is guidance-only: Skip must always be available.
            XCTAssertTrue(app.buttons["Skip camera setup"].exists, "Skip camera setup missing")
        }

        // Back out to the source picker, then close the flow (writes back to PracticeRouter).
        let cancel = app.buttons["Cancel setup"].exists ? app.buttons["Cancel setup"]
            : (app.buttons["GO BACK"].exists ? app.buttons["GO BACK"] : app.buttons["Not now"])
        if cancel.exists {
            cancel.tap()
            let close = app.buttons["Close"]
            if close.waitForExistence(timeout: 5) { close.tap() }
            XCTAssertTrue(startAssessment.waitForExistence(timeout: 10), "Did not return to Practice tab")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Helpers

    @MainActor
    private func completeOnboarding(_ app: XCUIApplication) {
        // Hook: CONTINUE unlocks once the last promise scrolls into view.
        let hookContinue = button(app, prefix: "CONTINUE")
        XCTAssertTrue(hookContinue.waitForExistence(timeout: 15), "Onboarding hook never appeared")
        for _ in 0..<6 where !hookContinue.isEnabled {
            app.swipeUp()
        }
        waitEnabled(hookContinue)
        hookContinue.tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Sam")
        next(app)

        tap(app.buttons["dupr-intermediate"])
        next(app)
        tap(button(app, prefix: "Aggressive"))
        next(app)
        tap(button(app, prefix: "1–2 times a week"))
        next(app)
        tap(button(app, prefix: "Dinking"))
        next(app)
        tap(button(app, prefix: "I make too many unforced errors"))
        next(app)
        next(app) // radar gaps
        next(app) // radar path
        tap(button(app, prefix: "1–2 hours"))
        next(app)
        next(app) // advantage
        tap(button(app, prefix: "Fewer unforced errors"))
        next(app)

        // Analyzing advances itself, then the plan screen.
        let seePlan = button(app, prefix: "SEE MY FULL PLAN")
        XCTAssertTrue(seePlan.waitForExistence(timeout: 20), "Plan screen never appeared")
        seePlan.tap()

        let limited = app.buttons["Continue with limited access"]
        XCTAssertTrue(limited.waitForExistence(timeout: 10), "Paywall never appeared")
        limited.tap()
    }

    @MainActor
    private func button(_ app: XCUIApplication, prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func next(_ app: XCUIApplication) {
        let nextButton = button(app, prefix: "NEXT")
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5), "NEXT not found")
        waitEnabled(nextButton)
        nextButton.tap()
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing element \(element)")
        element.tap()
    }

    @MainActor
    private func waitEnabled(_ element: XCUIElement) {
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"),
                                  evaluatedWith: element)
        wait(for: [enabled], timeout: 5)
    }

    @MainActor
    private func allowCameraIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 5) {
            let allow = alert.buttons["Allow"]
            if allow.exists { allow.tap() } else { alert.buttons.element(boundBy: 1).tap() }
        }
    }
}
