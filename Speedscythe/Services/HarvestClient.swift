import Foundation

enum HarvestError: Error {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case api(status: Int, message: String)
    case network(URLError)
}

extension HarvestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Harvest did not accept the access token. Connect again."
        case .rateLimited:
            "Harvest received too many requests. Try again in a moment."
        case .api(let status, let message):
            message.isEmpty ? "Harvest returned HTTP status \(status)." : message
        case .network(let error):
            error.localizedDescription
        }
    }
}

private protocol PageWithLinks: Decodable {
    var nextURL: URL? { get }
}

struct HarvestClient {
    let accessToken: String
    let accountID: Int

    func currentUser() async throws -> User {
        try await Self.send(URL(string: "https://api.harvestapp.com/v2/users/me")!, accessToken: accessToken, accountID: accountID)
    }

    func company() async throws -> Company {
        try await Self.send(URL(string: "https://api.harvestapp.com/v2/company")!, accessToken: accessToken, accountID: accountID)
    }

    func projectAssignments() async throws -> [ProjectAssignment] {
        let pages: [ProjectAssignmentsPage] = try await allPages(from: URL(string: "https://api.harvestapp.com/v2/users/me/project_assignments?per_page=2000")!)
        return pages.flatMap(\.projectAssignments)
    }

    func recentTimeEntries(userID: Int, from: String) async throws -> [TimeEntry] {
        try await timeEntries([URLQueryItem(name: "user_id", value: String(userID)), URLQueryItem(name: "from", value: from)])
    }

    func runningTimeEntries(userID: Int) async throws -> [TimeEntry] {
        try await timeEntries([URLQueryItem(name: "user_id", value: String(userID)), URLQueryItem(name: "is_running", value: "true")])
    }

    func createTimeEntry(projectID: Int, taskID: Int, spentDate: String) async throws -> TimeEntry {
        let body = try JSONEncoder().encode(NewTimeEntry(projectID: projectID, taskID: taskID, spentDate: spentDate))
        return try await Self.send(URL(string: "https://api.harvestapp.com/v2/time_entries")!, method: "POST", body: body, accessToken: accessToken, accountID: accountID)
    }

    func restartTimeEntry(id: Int) async throws -> TimeEntry {
        try await Self.send(URL(string: "https://api.harvestapp.com/v2/time_entries/\(id)/restart")!, method: "PATCH", accessToken: accessToken, accountID: accountID)
    }

    func stopTimeEntry(id: Int) async throws -> TimeEntry {
        try await Self.send(URL(string: "https://api.harvestapp.com/v2/time_entries/\(id)/stop")!, method: "PATCH", accessToken: accessToken, accountID: accountID)
    }

    static func accounts(accessToken: String) async throws -> [HarvestAccount] {
        let response: AccountsResponse = try await send(URL(string: "https://id.getharvest.com/api/v2/accounts")!, accessToken: accessToken, accountID: nil)
        return response.accounts
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private struct AccountsResponse: Decodable {
        let accounts: [HarvestAccount]
    }

    private struct NewTimeEntry: Encodable {
        let projectID: Int
        let taskID: Int
        let spentDate: String

        enum CodingKeys: String, CodingKey {
            case projectID = "project_id"
            case taskID = "task_id"
            case spentDate = "spent_date"
        }
    }

    private struct Links: Decodable {
        let next: URL?
    }

    private struct ProjectAssignmentsPage: PageWithLinks {
        let projectAssignments: [ProjectAssignment]
        let links: Links
        var nextURL: URL? { links.next }
    }

    private struct TimeEntriesPage: PageWithLinks {
        let timeEntries: [TimeEntry]
        let links: Links
        var nextURL: URL? { links.next }
    }

    private func timeEntries(_ queryItems: [URLQueryItem]) async throws -> [TimeEntry] {
        var components = URLComponents(string: "https://api.harvestapp.com/v2/time_entries")!
        components.queryItems = queryItems + [URLQueryItem(name: "per_page", value: "2000")]
        let pages: [TimeEntriesPage] = try await allPages(from: components.url!)
        return pages.flatMap(\.timeEntries)
    }

    private func allPages<Page: PageWithLinks>(from firstURL: URL) async throws -> [Page] {
        var pages: [Page] = []
        var nextURL: URL? = firstURL
        while let url = nextURL {
            let page: Page = try await Self.send(url, accessToken: accessToken, accountID: accountID)
            pages.append(page)
            nextURL = page.nextURL
        }
        return pages
    }

    private static func send<Response: Decodable>(
        _ url: URL,
        method: String = "GET",
        body: Data? = nil,
        accessToken: String,
        accountID: Int?
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(HarvestOAuth.userAgent, forHTTPHeaderField: "User-Agent")
        if let accountID {
            request.setValue(String(accountID), forHTTPHeaderField: "Harvest-Account-Id")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw HarvestError.network(error)
        }

        let httpResponse = response as! HTTPURLResponse
        switch httpResponse.statusCode {
        case 200..<300:
            return try decoder.decode(Response.self, from: data)
        case 401:
            throw HarvestError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw HarvestError.rateLimited(retryAfter: retryAfter)
        default:
            throw HarvestError.api(status: httpResponse.statusCode, message: String(decoding: data, as: UTF8.self))
        }
    }
}
