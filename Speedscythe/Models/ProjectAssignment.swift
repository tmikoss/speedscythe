import Foundation

struct ProjectAssignment: Codable, Equatable {
    let id: Int
    let isActive: Bool
    let project: Project
    let client: Client
    let taskAssignments: [TaskAssignment]
}

struct TaskAssignment: Codable, Equatable {
    let id: Int
    let isActive: Bool
    let task: HarvestTask
}
