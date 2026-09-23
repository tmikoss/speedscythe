import AppKit
import Observation
import os

@MainActor
@Observable
final class AppStore {
    let auth: AuthService
    private(set) var user: User?
    private(set) var company: Company?
    private(set) var assignments: [ProjectAssignment] = []
    private(set) var recentEntries: [TimeEntry] = []
    private(set) var runningEntry: TimeEntry?
    private(set) var runningEntryFetchedAt: Date?
    private(set) var lastRefresh: Date?
    private(set) var errorMessage: String?
    private(set) var today = Date.now.spentDate
    private(set) var isRefreshing = false

    var todayEntries: [TimeEntry] {
        recentEntries.filter { $0.spentDate == today }
    }

    var recentProjectOrder: [Int] {
        Self.recentProjectOrder(
            entries: recentEntries,
            activeProjectIDs: Set(assignments.filter(\.isActive).map(\.project.id))
        )
    }

    var lastTaskEntry: TimeEntry? {
        Self.lastTaskEntry(
            entries: recentEntries,
            runningEntry: runningEntry,
            activeProjectIDs: Set(assignments.filter(\.isActive).map(\.project.id))
        )
    }

    @ObservationIgnored private let cache = CacheStore(fileURL: CacheStore.defaultFileURL)
    @ObservationIgnored private var needsAnotherRefresh = false
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "store")

    init(auth: AuthService) {
        self.auth = auth
    }

    func start() {
        auth.onSessionChange = { [weak self] in
            self?.sessionChanged()
        }
        auth.restore()
        if auth.session != nil {
            loadCache()
        }
        sessionChanged()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshInBackground()
            }
        }
        observers = [
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshInBackground()
                }
            },
            NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.today = Date.now.spentDate
                    self?.refreshInBackground()
                }
            },
        ]
    }

    func refreshInBackground() {
        Task { await refresh() }
    }

    func refresh() async {
        guard !isRefreshing else {
            needsAnotherRefresh = true
            return
        }
        isRefreshing = true
        repeat {
            needsAnotherRefresh = false
            await fetchAll()
        } while needsAnotherRefresh
        isRefreshing = false
    }

    func runningElapsed(at date: Date) -> TimeInterval? {
        guard let runningEntry, let runningEntryFetchedAt else { return nil }
        return runningEntry.hours * 3600 + date.timeIntervalSince(runningEntryFetchedAt)
    }

    func todayDuration(projectID: Int, taskID: Int) -> TimeInterval {
        todayEntries
            .filter { !$0.isRunning && $0.project.id == projectID && $0.task.id == taskID }
            .reduce(0) { $0 + $1.hours * 3600 }
    }

    func reportError(_ message: String) {
        errorMessage = message
    }

    private func fetchAll() async {
        guard let session = auth.session else { return }
        let client = HarvestClient(accessToken: session.accessToken, accountID: session.accountID)
        let recentFrom = Calendar.current.date(byAdding: .day, value: -30, to: .now)!.spentDate
        do {
            async let fetchedCompany = client.company()
            async let fetchedAssignments = client.projectAssignments()
            let fetchedUser = try await client.currentUser()
            async let fetchedRecentEntries = client.recentTimeEntries(userID: fetchedUser.id, from: recentFrom)
            async let fetchedRunningEntries = client.runningTimeEntries(userID: fetchedUser.id)

            let runningEntries = try await fetchedRunningEntries
            let snapshot = CacheSnapshot(
                user: fetchedUser,
                company: try await fetchedCompany,
                assignments: try await fetchedAssignments,
                recentEntries: try await fetchedRecentEntries,
                runningEntry: runningEntries.first,
                lastRefresh: .now
            )
            guard auth.session == session else { return }

            apply(snapshot)
            today = Date.now.spentDate
            errorMessage = nil
            logger.info("Harvest account uses timestamp timers: \(snapshot.company?.wantsTimestampTimers ?? false, privacy: .public)")
            try cache.save(snapshot)
        } catch HarvestError.unauthorized {
            sessionRejected()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func recentProjectOrder(entries: [TimeEntry], activeProjectIDs: Set<Int>) -> [Int] {
        var latestUpdate: [Int: Date] = [:]
        for entry in entries where activeProjectIDs.contains(entry.project.id) {
            latestUpdate[entry.project.id] = max(latestUpdate[entry.project.id] ?? .distantPast, entry.updatedAt)
        }
        return latestUpdate
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)
    }

    static func lastTaskEntry(entries: [TimeEntry], runningEntry: TimeEntry?, activeProjectIDs: Set<Int>) -> TimeEntry? {
        entries
            .filter { entry in
                activeProjectIDs.contains(entry.project.id)
                    && (entry.project.id != runningEntry?.project.id || entry.task.id != runningEntry?.task.id)
            }
            .max { $0.updatedAt < $1.updatedAt }
    }

    private func sessionChanged() {
        if auth.session != nil {
            refreshInBackground()
        } else {
            apply(CacheSnapshot())
            do {
                try cache.delete()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadCache() {
        do {
            if let snapshot = try cache.load() {
                apply(snapshot)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ snapshot: CacheSnapshot) {
        user = snapshot.user
        company = snapshot.company
        assignments = snapshot.assignments
        recentEntries = snapshot.recentEntries
        runningEntry = snapshot.runningEntry
        runningEntryFetchedAt = snapshot.lastRefresh
        lastRefresh = snapshot.lastRefresh
    }
}

extension AppStore: TimerContext {
    var session: AuthSession? { auth.session }

    func apply(updatedEntry: TimeEntry) {
        if let index = recentEntries.firstIndex(where: { $0.id == updatedEntry.id }) {
            recentEntries[index] = updatedEntry
        } else {
            recentEntries.append(updatedEntry)
        }
        if updatedEntry.isRunning {
            runningEntry = updatedEntry
            runningEntryFetchedAt = .now
        } else if runningEntry?.id == updatedEntry.id {
            runningEntry = nil
        }
    }

    func sessionRejected() {
        auth.disconnect()
        errorMessage = HarvestError.unauthorized.localizedDescription
    }
}
