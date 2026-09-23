import XCTest
@testable import Speedscythe

@MainActor
final class LastTaskEntryTests: XCTestCase {
    func testPicksTheMostRecentlyUpdatedEntry() {
        let entries = [
            TestData.entry(id: 1, projectID: 100, taskID: 101, updatedAt: 100),
            TestData.entry(id: 2, projectID: 200, taskID: 201, updatedAt: 300),
            TestData.entry(id: 3, projectID: 100, taskID: 102, updatedAt: 200),
        ]

        let entry = AppStore.lastTaskEntry(entries: entries, runningEntry: nil, activeProjectIDs: [100, 200])

        XCTAssertEqual(entry?.id, 2)
    }

    func testSkipsTheRunningTask() {
        let running = TestData.entry(id: 3, projectID: 100, taskID: 101, isRunning: true, updatedAt: 300)
        let entries = [
            TestData.entry(id: 1, projectID: 200, taskID: 201, updatedAt: 100),
            TestData.entry(id: 2, projectID: 100, taskID: 101, updatedAt: 200),
            running,
        ]

        let entry = AppStore.lastTaskEntry(entries: entries, runningEntry: running, activeProjectIDs: [100, 200])

        XCTAssertEqual(entry?.id, 1)
    }

    func testKeepsAnotherTaskOfTheRunningProject() {
        let running = TestData.entry(id: 3, projectID: 100, taskID: 101, isRunning: true, updatedAt: 300)
        let entries = [
            TestData.entry(id: 1, projectID: 200, taskID: 201, updatedAt: 100),
            TestData.entry(id: 2, projectID: 100, taskID: 102, updatedAt: 200),
            running,
        ]

        let entry = AppStore.lastTaskEntry(entries: entries, runningEntry: running, activeProjectIDs: [100, 200])

        XCTAssertEqual(entry?.id, 2)
    }

    func testSkipsProjectsThatAreNoLongerAssigned() {
        let entries = [
            TestData.entry(id: 1, projectID: 100, taskID: 101, updatedAt: 100),
            TestData.entry(id: 2, projectID: 200, taskID: 201, updatedAt: 200),
        ]

        let entry = AppStore.lastTaskEntry(entries: entries, runningEntry: nil, activeProjectIDs: [100])

        XCTAssertEqual(entry?.id, 1)
    }

    func testIsNilWithoutOtherTasks() {
        let running = TestData.entry(id: 1, projectID: 100, taskID: 101, isRunning: true, updatedAt: 100)

        XCTAssertNil(AppStore.lastTaskEntry(entries: [running], runningEntry: running, activeProjectIDs: [100]))
    }
}
