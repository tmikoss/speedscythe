import Foundation

enum TimerAction: Equatable {
    case keepRunning
    case restart(entryID: Int)
    case create
}

enum TimerDecision {
    static func action(projectID: Int, taskID: Int, runningEntry: TimeEntry?, todayEntries: [TimeEntry], continueToday: Bool) -> TimerAction {
        if let runningEntry, runningEntry.project.id == projectID, runningEntry.task.id == taskID {
            return .keepRunning
        }
        if continueToday,
           let entry = todayEntries
               .filter({ !$0.isRunning && !$0.isLocked && $0.project.id == projectID && $0.task.id == taskID })
               .max(by: { $0.updatedAt < $1.updatedAt }) {
            return .restart(entryID: entry.id)
        }
        return .create
    }
}
