import Foundation

struct BoardModel: Equatable {
    struct Column: Equatable, Identifiable {
        let project: Project
        let client: Client
        let showsClientName: Bool
        let tasks: [HarvestTask]

        var id: Int { project.id }
    }

    static let maxVisibleTiles = 6

    let columns: [Column]

    var visibleRowCount: Int {
        min(Self.maxVisibleTiles, columns.map(\.tasks.count).max() ?? 0)
    }

    var maxTaskKeyCount: Int {
        min(9, columns.map(\.tasks.count).max() ?? 0)
    }

    init(assignments: [ProjectAssignment], projectOrder: [Int], slotCount: Int) {
        let assignmentsByProject = Dictionary(
            assignments.filter(\.isActive).map { ($0.project.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let visible = projectOrder.compactMap { assignmentsByProject[$0] }.prefix(slotCount)
        let nameCounts = Dictionary(visible.map { ($0.project.name, 1) }, uniquingKeysWith: +)
        columns = visible.map { assignment in
            Column(
                project: assignment.project,
                client: assignment.client,
                showsClientName: nameCounts[assignment.project.name, default: 0] > 1,
                tasks: assignment.taskAssignments.filter(\.isActive).map(\.task)
            )
        }
    }
}
