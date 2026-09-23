import Foundation

struct TimeEntry: Codable, Equatable {
    let id: Int
    let spentDate: String
    let hours: Double
    let notes: String?
    let isRunning: Bool
    let isLocked: Bool
    let updatedAt: Date
    let project: Project
    let task: HarvestTask
    let client: Client
}

extension Date {
    var spentDate: String {
        formatted(Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent).year().month().day())
    }
}
