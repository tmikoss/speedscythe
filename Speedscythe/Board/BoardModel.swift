import Foundation

struct BoardModel: Equatable {
    struct Column: Equatable, Identifiable {
        let slot: Int
        let project: Project
        let client: Client
        let showsClientName: Bool
        let tasks: [HarvestTask]

        var id: Int { project.id }
        var number: Int { slot + 1 }
    }

    static let maxVisibleTiles = 6

    let columns: [Column]

    var visibleRowCount: Int {
        min(Self.maxVisibleTiles, columns.map(\.tasks.count).max() ?? 0)
    }

    var maxTaskKeyCount: Int {
        min(9, columns.map(\.tasks.count).max() ?? 0)
    }

    var maxProjectNumber: Int {
        columns.last?.number ?? 0
    }

    init(assignments: [ProjectAssignment], slots: [Int?], taskOrders: [Int: [Int]] = [:]) {
        let assignmentsByProject = Dictionary(
            assignments.filter(\.isActive).map { ($0.project.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let visible = slots.enumerated().compactMap { slot, projectID in
            projectID.flatMap { assignmentsByProject[$0] }.map { (slot, $0) }
        }
        let nameCounts = Dictionary(visible.map { ($0.1.project.name, 1) }, uniquingKeysWith: +)
        columns = visible.map { slot, assignment in
            Column(
                slot: slot,
                project: assignment.project,
                client: assignment.client,
                showsClientName: nameCounts[assignment.project.name, default: 0] > 1,
                tasks: Self.ordered(assignment.taskAssignments.filter(\.isActive).map(\.task), by: taskOrders[assignment.project.id] ?? [])
            )
        }
    }

    private static func ordered(_ tasks: [HarvestTask], by order: [Int]) -> [HarvestTask] {
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let ranked = tasks.filter { rank[$0.id] != nil }.sorted { rank[$0.id, default: 0] < rank[$1.id, default: 0] }
        return ranked + tasks.filter { rank[$0.id] == nil }
    }

    func columnIndex(forNumber number: Int) -> Int? {
        columns.firstIndex { $0.number == number }
    }
}
