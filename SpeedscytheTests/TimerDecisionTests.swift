import XCTest
@testable import Speedscythe

final class TimerDecisionTests: XCTestCase {
    func testKeepsRunningEntryForSameProjectAndTask() {
        let running = TestData.entry(id: 1, projectID: 10, taskID: 20, isRunning: true)

        let action = TimerDecision.action(projectID: 10, taskID: 20, runningEntry: running, todayEntries: [running], continueToday: true)

        XCTAssertEqual(action, .keepRunning)
    }

    func testRestartsMostRecentlyUpdatedStoppedEntryToday() {
        let entries = [
            TestData.entry(id: 1, projectID: 10, taskID: 20, updatedAt: 100),
            TestData.entry(id: 2, projectID: 10, taskID: 20, updatedAt: 300),
            TestData.entry(id: 3, projectID: 10, taskID: 20, updatedAt: 200),
        ]

        let action = TimerDecision.action(projectID: 10, taskID: 20, runningEntry: nil, todayEntries: entries, continueToday: true)

        XCTAssertEqual(action, .restart(entryID: 2))
    }

    func testRestartsTodayEntryWhileAnotherTimerRuns() {
        let running = TestData.entry(id: 1, projectID: 10, taskID: 99, isRunning: true)
        let stopped = TestData.entry(id: 2, projectID: 10, taskID: 20)

        let action = TimerDecision.action(projectID: 10, taskID: 20, runningEntry: running, todayEntries: [running, stopped], continueToday: true)

        XCTAssertEqual(action, .restart(entryID: 2))
    }

    func testSkipsLockedEntries() {
        let locked = TestData.entry(id: 1, projectID: 10, taskID: 20, isLocked: true)

        let action = TimerDecision.action(projectID: 10, taskID: 20, runningEntry: nil, todayEntries: [locked], continueToday: true)

        XCTAssertEqual(action, .create)
    }

    func testCreatesWhenContinueTodayIsOff() {
        let stopped = TestData.entry(id: 1, projectID: 10, taskID: 20)

        let action = TimerDecision.action(projectID: 10, taskID: 20, runningEntry: nil, todayEntries: [stopped], continueToday: false)

        XCTAssertEqual(action, .create)
    }

    func testCreatesForOtherTaskInSameProject() {
        let stopped = TestData.entry(id: 1, projectID: 10, taskID: 21)

        let action = TimerDecision.action(projectID: 10, taskID: 20, runningEntry: nil, todayEntries: [stopped], continueToday: true)

        XCTAssertEqual(action, .create)
    }
}
