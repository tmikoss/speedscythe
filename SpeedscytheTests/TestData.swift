import Foundation
@testable import Speedscythe

enum TestData {
    static func entry(
        id: Int,
        projectID: Int,
        taskID: Int,
        spentDate: String = Date.now.spentDate,
        hours: Double = 1,
        notes: String? = nil,
        isRunning: Bool = false,
        isLocked: Bool = false,
        updatedAt: TimeInterval = 0
    ) -> TimeEntry {
        TimeEntry(
            id: id,
            spentDate: spentDate,
            hours: hours,
            notes: notes,
            isRunning: isRunning,
            isLocked: isLocked,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            project: Project(id: projectID, name: "Project \(projectID)", code: nil),
            task: HarvestTask(id: taskID, name: "Task \(taskID)"),
            client: Client(id: 1, name: "Client")
        )
    }

    static func board(taskCounts: [Int]) -> BoardModel {
        let assignments = taskCounts.enumerated().map { index, count in
            ProjectAssignment(
                id: index + 1,
                isActive: true,
                project: Project(id: (index + 1) * 100, name: "Project \(index + 1)", code: nil),
                client: Client(id: 1, name: "Client"),
                taskAssignments: (0..<count).map { task in
                    TaskAssignment(id: task + 1, isActive: true, task: HarvestTask(id: (index + 1) * 100 + task + 1, name: "Task \(task + 1)"))
                }
            )
        }
        return BoardModel(assignments: assignments, slots: assignments.map(\.project.id))
    }
}
