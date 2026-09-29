import XCTest
@testable import Speedscythe

final class TaskMatcherTests: XCTestCase {
    private let assignments = [
        TaskMatcherTests.assignment(projectID: 100, project: "Speedscythe", client: "Mitigate", tasks: [(101, "Development"), (102, "Design review")]),
        TaskMatcherTests.assignment(projectID: 200, project: "Spectre", client: "Acme", tasks: [(201, "DevOps"), (202, "Meetings")]),
        TaskMatcherTests.assignment(projectID: 300, project: "Café Menu", client: "Bistro", tasks: [(301, "Webdev")]),
    ]

    func testEveryTokenMustMatchSomeField() {
        let ids = matchIDs("spe dev")

        XCTAssertEqual(Set(ids), ["100-101", "200-201"])
    }

    func testMatchesTheClientName() {
        XCTAssertEqual(matchIDs("acme meet"), ["200-202"])
    }

    func testIgnoresCaseAndDiacritics() {
        XCTAssertEqual(matchIDs("CAFE"), ["300-301"])
    }

    func testWordStartMatchesRankFirst() {
        XCTAssertEqual(matchIDs("dev"), ["100-101", "200-201", "300-301"])
    }

    func testRecentTaskRanksFirstAmongEqualMatches() {
        let entries = [
            TestData.entry(id: 1, projectID: 200, taskID: 201, updatedAt: 200),
            TestData.entry(id: 2, projectID: 100, taskID: 101, updatedAt: 100),
        ]

        XCTAssertEqual(matchIDs("dev", entries: entries), ["200-201", "100-101", "300-301"])
    }

    func testRecentProjectRanksFirstAmongUnusedTasks() {
        let entries = [TestData.entry(id: 1, projectID: 200, taskID: 202, updatedAt: 100)]

        XCTAssertEqual(matchIDs("d", entries: entries).prefix(2), ["200-201", "100-101"])
    }

    func testSkipsInactiveProjectsAndTasks() {
        let assignments = [
            Self.assignment(projectID: 100, project: "Active", client: "C", tasks: [(101, "Task")], isActive: true),
            Self.assignment(projectID: 200, project: "Inactive", client: "C", tasks: [(201, "Task")], isActive: false),
            ProjectAssignment(
                id: 300,
                isActive: true,
                project: Project(id: 300, name: "Partial", code: nil),
                client: Client(id: 1, name: "C"),
                taskAssignments: [TaskAssignment(id: 301, isActive: false, task: HarvestTask(id: 301, name: "Task"))]
            ),
        ]

        let ids = TaskMatcher.matches(query: "task", assignments: assignments, recentEntries: [], runningEntry: nil).map(\.id)

        XCTAssertEqual(ids, ["100-101"])
    }

    func testEmptyQueryListsRecentTasksWithoutTheRunningTask() {
        let running = TestData.entry(id: 3, projectID: 100, taskID: 101, isRunning: true, updatedAt: 300)
        let entries = [
            TestData.entry(id: 1, projectID: 200, taskID: 202, updatedAt: 100),
            TestData.entry(id: 2, projectID: 300, taskID: 301, updatedAt: 200),
            running,
        ]

        let ids = TaskMatcher.matches(query: "  ", assignments: assignments, recentEntries: entries, runningEntry: running).map(\.id)

        XCTAssertEqual(ids, ["300-301", "200-202"])
    }

    func testEmptyQueryWithoutRecentTasksListsTheFirstAvailableTasks() {
        let running = TestData.entry(id: 1, projectID: 100, taskID: 101, isRunning: true, updatedAt: 100)

        let ids = TaskMatcher.matches(query: "", assignments: assignments, recentEntries: [running], runningEntry: running).map(\.id)

        XCTAssertEqual(ids, ["100-102", "200-201", "200-202", "300-301"])
    }

    func testLimitsTheResultCount() {
        let many = [Self.assignment(projectID: 100, project: "P", client: "C", tasks: (1...10).map { (100 + $0, "Task \($0)") })]

        XCTAssertEqual(TaskMatcher.matches(query: "task", assignments: many, recentEntries: [], runningEntry: nil).count, TaskMatcher.maxResults)
    }

    private func matchIDs(_ query: String, entries: [TimeEntry] = []) -> [String] {
        TaskMatcher.matches(query: query, assignments: assignments, recentEntries: entries, runningEntry: nil).map(\.id)
    }

    private static func assignment(projectID: Int, project: String, client: String, tasks: [(Int, String)], isActive: Bool = true) -> ProjectAssignment {
        ProjectAssignment(
            id: projectID,
            isActive: isActive,
            project: Project(id: projectID, name: project, code: nil),
            client: Client(id: projectID, name: client),
            taskAssignments: tasks.map { TaskAssignment(id: $0.0, isActive: true, task: HarvestTask(id: $0.0, name: $0.1)) }
        )
    }
}
