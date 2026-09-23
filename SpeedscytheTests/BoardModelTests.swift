import XCTest
@testable import Speedscythe

final class BoardModelTests: XCTestCase {
    func testBuildsColumnsInSlotOrder() {
        let board = BoardModel(
            assignments: [assignment(projectID: 1), assignment(projectID: 2), assignment(projectID: 3)],
            slots: [3, 1]
        )

        XCTAssertEqual(board.columns.map(\.project.id), [3, 1])
        XCTAssertEqual(board.columns.map(\.number), [1, 2])
    }

    func testKeepsSlotNumbersAcrossEmptySlots() {
        let board = BoardModel(
            assignments: [assignment(projectID: 1), assignment(projectID: 2)],
            slots: [1, nil, 2]
        )

        XCTAssertEqual(board.columns.map(\.number), [1, 3])
        XCTAssertEqual(board.columnIndex(forNumber: 3), 1)
        XCTAssertNil(board.columnIndex(forNumber: 2))
        XCTAssertEqual(board.maxProjectNumber, 3)
    }

    func testSkipsProjectsWithoutActiveAssignment() {
        let board = BoardModel(
            assignments: [assignment(projectID: 1), assignment(projectID: 2, isActive: false)],
            slots: [2, 1, 9]
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
            slots: [1]
        )

        XCTAssertEqual(board.columns.first?.tasks.map(\.id), [30, 10])
    }

    func testSavedTaskOrderComesFirstAndNewTasksFollowInAPIOrder() {
        let board = BoardModel(
            assignments: [
                assignment(projectID: 1, tasks: [10, 20, 30, 40].map { TaskAssignment(id: $0, isActive: true, task: HarvestTask(id: $0, name: "Task \($0)")) }),
                assignment(projectID: 2),
            ],
            slots: [1, 2],
            taskOrders: [1: [30, 99, 10]]
        )

        XCTAssertEqual(board.columns[0].tasks.map(\.id), [30, 10, 20, 40])
        XCTAssertEqual(board.columns[1].tasks.map(\.id), [1])
    }

    func testShowsClientNameOnlyForDuplicateProjectNames() {
        let board = BoardModel(
            assignments: [
                assignment(projectID: 1, name: "Website"),
                assignment(projectID: 2, name: "Website"),
                assignment(projectID: 3, name: "Support"),
            ],
            slots: [1, 2, 3]
        )

        XCTAssertEqual(board.columns.map(\.showsClientName), [true, true, false])
    }

    func testCapsVisibleRowsAtSixAndTaskKeysAtNine() {
        let tasks = (1...12).map { TaskAssignment(id: $0, isActive: true, task: HarvestTask(id: $0, name: "Task \($0)")) }
        let board = BoardModel(assignments: [assignment(projectID: 1, tasks: tasks)], slots: [1])

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
