import Foundation

struct TaskMatch: Equatable, Identifiable {
    let project: Project
    let client: Client
    let task: HarvestTask

    var id: String { "\(project.id)-\(task.id)" }
}

enum TaskMatcher {
    static let maxResults = 6

    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    static func matches(query: String, assignments: [ProjectAssignment], recentEntries: [TimeEntry], runningEntry: TimeEntry?) -> [TaskMatch] {
        let candidates = assignments.filter(\.isActive).flatMap { assignment in
            assignment.taskAssignments.filter(\.isActive).map { TaskMatch(project: assignment.project, client: assignment.client, task: $0.task) }
        }
        var taskUpdates: [String: Date] = [:]
        var projectUpdates: [Int: Date] = [:]
        for entry in recentEntries {
            let key = "\(entry.project.id)-\(entry.task.id)"
            taskUpdates[key] = max(taskUpdates[key] ?? .distantPast, entry.updatedAt)
            projectUpdates[entry.project.id] = max(projectUpdates[entry.project.id] ?? .distantPast, entry.updatedAt)
        }

        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else {
            let runningKey = runningEntry.map { "\($0.project.id)-\($0.task.id)" }
            let available = candidates.filter { $0.id != runningKey }
            let recent = available.compactMap { candidate in
                taskUpdates[candidate.id].map { (match: candidate, updatedAt: $0) }
            }
            guard !recent.isEmpty else { return Array(available.prefix(maxResults)) }
            return recent
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(maxResults)
                .map(\.match)
        }

        let ranked = candidates.enumerated().compactMap { index, candidate -> (match: TaskMatch, wordStarts: Int, index: Int)? in
            let fields = [candidate.client.name, candidate.project.name, candidate.task.name]
            guard tokens.allSatisfy({ token in fields.contains { $0.range(of: token, options: options) != nil } }) else { return nil }
            let words = fields.flatMap { $0.split { !$0.isLetter && !$0.isNumber } }
            let wordStarts = tokens.filter { token in words.contains { $0.range(of: token, options: options.union(.anchored)) != nil } }.count
            return (candidate, wordStarts, index)
        }
        return ranked
            .sorted { lhs, rhs in
                if lhs.wordStarts != rhs.wordStarts {
                    return lhs.wordStarts > rhs.wordStarts
                }
                let lhsTask = taskUpdates[lhs.match.id] ?? .distantPast
                let rhsTask = taskUpdates[rhs.match.id] ?? .distantPast
                if lhsTask != rhsTask {
                    return lhsTask > rhsTask
                }
                let lhsProject = projectUpdates[lhs.match.project.id] ?? .distantPast
                let rhsProject = projectUpdates[rhs.match.project.id] ?? .distantPast
                if lhsProject != rhsProject {
                    return lhsProject > rhsProject
                }
                return lhs.index < rhs.index
            }
            .prefix(maxResults)
            .map(\.match)
    }
}
