import XCTest
@testable import Speedscythe

@MainActor
final class TimerServiceTests: XCTestCase {
    private var context: FakeTimerContext!
    private var api: FakeTimeEntryAPI!
    private var service: TimerService!

    override func setUp() async throws {
        context = FakeTimerContext()
        api = FakeTimeEntryAPI()
        service = TimerService(context: context, makeAPI: { [api] _ in api! }, continueToday: { true })
    }

    func testStartCreatesEntryForToday() async throws {
        api.response = TestData.entry(id: 5, projectID: 10, taskID: 20, isRunning: true)

        try await service.start(projectID: 10, taskID: 20, source: .picker)

        XCTAssertEqual(api.calls, [.create(projectID: 10, taskID: 20, spentDate: Date.now.spentDate)])
        XCTAssertEqual(context.appliedEntries.map(\.id), [5])
        XCTAssertEqual(context.refreshCount, 1)
    }

    func testStartRestartsStoppedEntryFromToday() async throws {
        context.todayEntries = [TestData.entry(id: 7, projectID: 10, taskID: 20)]
        api.response = TestData.entry(id: 8, projectID: 10, taskID: 20, isRunning: true)

        try await service.start(projectID: 10, taskID: 20, source: .picker)

        XCTAssertEqual(api.calls, [.restart(id: 7)])
        XCTAssertEqual(context.appliedEntries.map(\.id), [8])
    }

    func testStartDoesNothingWhenSameTimerRuns() async throws {
        context.runningEntry = TestData.entry(id: 1, projectID: 10, taskID: 20, isRunning: true)

        try await service.start(projectID: 10, taskID: 20, source: .picker)

        XCTAssertEqual(api.calls, [])
        XCTAssertEqual(context.refreshCount, 0)
    }

    func testStartWithoutSessionThrows() async {
        context.session = nil

        do {
            try await service.start(projectID: 10, taskID: 20, source: .picker)
            XCTFail("Expected an error")
        } catch {
            XCTAssertTrue(error is TimerError)
        }
        XCTAssertEqual(api.calls, [])
    }

    func testStopStopsRunningEntry() async throws {
        context.runningEntry = TestData.entry(id: 3, projectID: 10, taskID: 20, isRunning: true)
        api.response = TestData.entry(id: 3, projectID: 10, taskID: 20)

        try await service.stop()

        XCTAssertEqual(api.calls, [.stop(id: 3)])
        XCTAssertEqual(context.appliedEntries.map(\.isRunning), [false])
        XCTAssertEqual(context.refreshCount, 1)
    }

    func testSecondStopWhileFirstIsInFlightDoesNothing() async throws {
        context.runningEntry = TestData.entry(id: 3, projectID: 10, taskID: 20, isRunning: true)
        api.response = TestData.entry(id: 3, projectID: 10, taskID: 20)

        api.holdsStop = true
        let first = Task { try await service.stop() }
        while api.stopGate == nil {
            await Task.yield()
        }

        try await service.stop()
        api.stopGate?.resume()
        try await first.value

        XCTAssertEqual(api.calls, [.stop(id: 3)])
    }

    func testStopWithoutRunningEntryDoesNothing() async throws {
        try await service.stop()

        XCTAssertEqual(api.calls, [])
    }

    func testRejectedTokenOnStartRejectsSession() async {
        api.error = HarvestError.unauthorized

        do {
            try await service.start(projectID: 10, taskID: 20, source: .picker)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(context.rejectedSessionCount, 1)
        }
        XCTAssertEqual(context.appliedEntries.count, 0)
    }

    func testRejectedTokenOnStopRejectsSession() async {
        context.runningEntry = TestData.entry(id: 3, projectID: 10, taskID: 20, isRunning: true)
        api.error = HarvestError.unauthorized

        do {
            try await service.stop()
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(context.rejectedSessionCount, 1)
        }
    }

    func testOtherErrorsKeepSession() async {
        api.error = HarvestError.api(status: 422, message: "Invalid")

        do {
            try await service.start(projectID: 10, taskID: 20, source: .picker)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(context.rejectedSessionCount, 0)
        }
    }
}

@MainActor
private final class FakeTimerContext: TimerContext {
    var session: AuthSession? = AuthSession(accessToken: "token", expiresAt: .distantFuture, accountID: 1)
    var runningEntry: TimeEntry?
    var todayEntries: [TimeEntry] = []
    var appliedEntries: [TimeEntry] = []
    var refreshCount = 0
    var rejectedSessionCount = 0

    func apply(updatedEntry: TimeEntry) {
        appliedEntries.append(updatedEntry)
    }

    func refreshInBackground() {
        refreshCount += 1
    }

    func sessionRejected() {
        rejectedSessionCount += 1
    }
}

@MainActor
private final class FakeTimeEntryAPI: TimeEntryAPI {
    enum Call: Equatable {
        case create(projectID: Int, taskID: Int, spentDate: String)
        case restart(id: Int)
        case stop(id: Int)
    }

    var calls: [Call] = []
    var response = TestData.entry(id: 0, projectID: 0, taskID: 0)
    var error: Error?
    var holdsStop = false
    var stopGate: CheckedContinuation<Void, Never>?

    func createTimeEntry(projectID: Int, taskID: Int, spentDate: String) async throws -> TimeEntry {
        calls.append(.create(projectID: projectID, taskID: taskID, spentDate: spentDate))
        return try result()
    }

    func restartTimeEntry(id: Int) async throws -> TimeEntry {
        calls.append(.restart(id: id))
        return try result()
    }

    func stopTimeEntry(id: Int) async throws -> TimeEntry {
        calls.append(.stop(id: id))
        if holdsStop {
            await withCheckedContinuation { stopGate = $0 }
        }
        return try result()
    }

    private func result() throws -> TimeEntry {
        if let error {
            throw error
        }
        return response
    }
}
