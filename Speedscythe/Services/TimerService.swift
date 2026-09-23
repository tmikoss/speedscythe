import Foundation
import os

protocol TimeEntryAPI {
    func createTimeEntry(projectID: Int, taskID: Int, spentDate: String) async throws -> TimeEntry
    func restartTimeEntry(id: Int) async throws -> TimeEntry
    func stopTimeEntry(id: Int) async throws -> TimeEntry
}

extension HarvestClient: TimeEntryAPI {}

@MainActor
protocol TimerContext: AnyObject {
    var session: AuthSession? { get }
    var runningEntry: TimeEntry? { get }
    var todayEntries: [TimeEntry] { get }
    func apply(updatedEntry: TimeEntry)
    func refreshInBackground()
}

enum StartSource {
    case picker
}

enum TimerError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        "Connect your Harvest account in Settings."
    }
}

@MainActor
final class TimerService {
    private let context: TimerContext
    private let makeAPI: (AuthSession) -> TimeEntryAPI
    private let continueToday: () -> Bool
    private var isStopping = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "timer")

    init(
        context: TimerContext,
        makeAPI: @escaping (AuthSession) -> TimeEntryAPI = { HarvestClient(accessToken: $0.accessToken, accountID: $0.accountID) },
        continueToday: @escaping () -> Bool = { Preferences.continueToday }
    ) {
        self.context = context
        self.makeAPI = makeAPI
        self.continueToday = continueToday
    }

    func start(projectID: Int, taskID: Int, source: StartSource) async throws {
        guard let session = context.session else { throw TimerError.notConnected }
        let api = makeAPI(session)
        let action = TimerDecision.action(
            projectID: projectID,
            taskID: taskID,
            runningEntry: context.runningEntry,
            todayEntries: context.todayEntries,
            continueToday: continueToday()
        )
        let entry: TimeEntry
        switch action {
        case .keepRunning:
            return
        case .restart(let entryID):
            entry = try await api.restartTimeEntry(id: entryID)
            logger.info("S5 restart: requested entry \(entryID, privacy: .public), Harvest returned entry \(entry.id, privacy: .public)")
        case .create:
            entry = try await api.createTimeEntry(projectID: projectID, taskID: taskID, spentDate: Date.now.spentDate)
        }
        context.apply(updatedEntry: entry)
        context.refreshInBackground()
    }

    func stop() async throws {
        guard !isStopping, let session = context.session, let runningEntry = context.runningEntry else { return }
        isStopping = true
        defer { isStopping = false }
        let entry = try await makeAPI(session).stopTimeEntry(id: runningEntry.id)
        context.apply(updatedEntry: entry)
        context.refreshInBackground()
    }
}
