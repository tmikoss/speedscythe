import XCTest
@testable import Speedscythe

@MainActor
final class RecentProjectOrderTests: XCTestCase {
    func testOrdersProjectsByMostRecentUpdate() {
        let entries = [
            entry(projectID: 1, updatedAt: 100),
            entry(projectID: 2, updatedAt: 200),
            entry(projectID: 1, updatedAt: 300),
            entry(projectID: 3, updatedAt: 150),
        ]

        let order = AppStore.recentProjectOrder(entries: entries, activeProjectIDs: [1, 2, 3])

        XCTAssertEqual(order, [1, 2, 3])
    }

    func testSkipsProjectsThatAreNoLongerAssigned() {
        let entries = [
            entry(projectID: 1, updatedAt: 100),
            entry(projectID: 2, updatedAt: 200),
        ]

        let order = AppStore.recentProjectOrder(entries: entries, activeProjectIDs: [1])

        XCTAssertEqual(order, [1])
    }

    func testBreaksTiesByProjectID() {
        let entries = [
            entry(projectID: 7, updatedAt: 100),
            entry(projectID: 3, updatedAt: 100),
        ]

        let order = AppStore.recentProjectOrder(entries: entries, activeProjectIDs: [3, 7])

        XCTAssertEqual(order, [3, 7])
    }

    private func entry(projectID: Int, updatedAt: TimeInterval) -> TimeEntry {
        TimeEntry(
            id: Int.random(in: 1...1_000_000),
            spentDate: "2026-09-23",
            hours: 1,
            notes: nil,
            isRunning: false,
            isLocked: false,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            project: Project(id: projectID, name: "Project \(projectID)", code: nil),
            task: HarvestTask(id: 1, name: "Task"),
            client: Client(id: 1, name: "Client")
        )
    }
}
