import XCTest
@testable import Speedscythe

final class DecodingTests: XCTestCase {
    func testDecodesCurrentUser() throws {
        let user = try decodeFixture(User.self, named: "users_me")

        XCTAssertEqual(user, User(id: 1_782_884, firstName: "Bob", lastName: "Powell"))
    }

    func testDecodesCompany() throws {
        let company = try decodeFixture(Company.self, named: "company")

        XCTAssertEqual(company, Company(name: "API Examples", wantsTimestampTimers: true))
    }

    func testDecodesAccounts() throws {
        let response = try decodeFixture(AccountsFixture.self, named: "accounts")

        XCTAssertEqual(response.accounts.first, HarvestAccount(id: 10254, name: "Sterling Cooper Advertising Agency", product: "harvest"))
        XCTAssertEqual(response.accounts.count, 2)
    }

    func testDecodesProjectAssignments() throws {
        let response = try decodeFixture(ProjectAssignmentsFixture.self, named: "project_assignments")

        XCTAssertEqual(response.projectAssignments, [
            ProjectAssignment(
                id: 125_066_109,
                isActive: true,
                project: Project(id: 14_308_069, name: "Online Store - Phase 1", code: "OS1"),
                client: Client(id: 5_735_776, name: "123 Industries"),
                taskAssignments: [
                    TaskAssignment(id: 155_505_013, isActive: true, task: HarvestTask(id: 8_083_365, name: "Graphic Design")),
                ]
            ),
        ])
    }

    func testDecodesTimeEntries() throws {
        let response = try decodeFixture(TimeEntriesFixture.self, named: "time_entries")

        XCTAssertEqual(response.timeEntries, [
            TimeEntry(
                id: 636_709_355,
                spentDate: "2017-03-02",
                hours: 2.11,
                notes: "Adding CSS styling",
                isRunning: false,
                isLocked: true,
                updatedAt: try Date("2017-06-27T16:47:14Z", strategy: .iso8601),
                project: Project(id: 14_307_913, name: "Marketing Website", code: nil),
                task: HarvestTask(id: 8_083_365, name: "Graphic Design"),
                client: Client(id: 5_735_774, name: "ABC Corp")
            ),
        ])
    }

    func testCacheRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CacheStore(fileURL: directory.appending(path: "cache.json"))
        let entries = try decodeFixture(TimeEntriesFixture.self, named: "time_entries").timeEntries
        let snapshot = CacheSnapshot(
            user: try decodeFixture(User.self, named: "users_me"),
            company: try decodeFixture(Company.self, named: "company"),
            assignments: try decodeFixture(ProjectAssignmentsFixture.self, named: "project_assignments").projectAssignments,
            recentEntries: entries,
            runningEntry: entries.first,
            lastRefresh: try Date("2026-09-23T10:00:00Z", strategy: .iso8601)
        )

        try store.save(snapshot)

        XCTAssertEqual(try store.load(), snapshot)
    }

    func testCacheLoadReturnsNilWithoutFile() throws {
        let store = CacheStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json"))

        XCTAssertNil(try store.load())
    }

    func testSpentDateUsesLocalCalendarDate() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 23, minute: 30))!

        XCTAssertEqual(date.spentDate, "2026-01-05")
    }

    private struct AccountsFixture: Decodable {
        let accounts: [HarvestAccount]
    }

    private struct ProjectAssignmentsFixture: Decodable {
        let projectAssignments: [ProjectAssignment]
    }

    private struct TimeEntriesFixture: Decodable {
        let timeEntries: [TimeEntry]
    }

    private func decodeFixture<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try HarvestClient.decoder.decode(type, from: Data(contentsOf: url))
    }
}
