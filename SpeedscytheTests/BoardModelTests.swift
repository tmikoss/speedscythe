import XCTest
@testable import Speedscythe

final class BoardModelTests: XCTestCase {
    func testOrdersColumnsByProjectOrderAndCapsAtSlotCount() {
        let board = BoardModel(
            assignments: [assignment(projectID: 1), assignment(projectID: 2), assignment(projectID: 3)],
            projectOrder: [3, 1, 2],
            slotCount: 2
        )

        XCTAssertEqual(board.columns.map(\.project.id), [3, 1])
    }

    func testSkipsProjectsWithoutActiveAssignment() {
        let board = BoardModel(
            assignments: [assignment(projectID: 1), assignment(projectID: 2, isActive: false)],
            projectOrder: [2, 1, 9],
            slotCount: 6
        )

        XCTAssertEqual(board.columns.map(\.project.id), [1])
    }

    func testKeepsActiveTasksInAPIOrder() {
        let board = BoardModel(
            assignments: [
                assignment(projectID: 1, tasks: [
                    TaskAssignment(id: 1, isActive: true, task: HarvestTask(id: 30, name: "Zeta")),
                    TaskAssignment(id: 2, isActive: false, task: HarvestTask(id: 20, name: "Archived")),
                    TaskAssignment(id: 3, isActive: true, task: HarvestTask(id: 10, name: "Alpha")),
                ]),
            ],
            projectOrder: [1],
            slotCount: 6
        )

        XCTAssertEqual(board.columns.first?.tasks.map(\.id), [30, 10])
    }

    func testShowsClientNameOnlyForDuplicateProjectNames() {
        let board = BoardModel(
            assignments: [
                assignment(projectID: 1, name: "Website"),
                assignment(projectID: 2, name: "Website"),
                assignment(projectID: 3, name: "Support"),
            ],
            projectOrder: [1, 2, 3],
            slotCount: 6
        )

        XCTAssertEqual(board.columns.map(\.showsClientName), [true, true, false])
    }

    func testCapsVisibleRowsAtSixAndTaskKeysAtNine() {
        let tasks = (1...12).map { TaskAssignment(id: $0, isActive: true, task: HarvestTask(id: $0, name: "Task \($0)")) }
        let board = BoardModel(assignments: [assignment(projectID: 1, tasks: tasks)], projectOrder: [1], slotCount: 6)

        XCTAssertEqual(board.visibleRowCount, 6)
        XCTAssertEqual(board.maxTaskKeyCount, 9)
    }

    private func assignment(
        projectID: Int,
        name: String? = nil,
        isActive: Bool = true,
        tasks: [TaskAssignment] = [TaskAssignment(id: 1, isActive: true, task: HarvestTask(id: 1, name: "Development"))]
    ) -> ProjectAssignment {
        ProjectAssignment(
            id: projectID * 100,
            isActive: isActive,
            project: Project(id: projectID, name: name ?? "Project \(projectID)", code: nil),
            client: Client(id: projectID * 10, name: "Client \(projectID)"),
            taskAssignments: tasks
        )
    }
}
