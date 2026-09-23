import Foundation

struct CacheSnapshot: Codable, Equatable {
    var user: User?
    var company: Company?
    var assignments: [ProjectAssignment] = []
    var recentEntries: [TimeEntry] = []
    var runningEntry: TimeEntry?
    var lastRefresh: Date?
}

struct CacheStore {
    let fileURL: URL

    static let defaultFileURL = URL.applicationSupportDirectory
        .appending(path: Bundle.main.bundleIdentifier!, directoryHint: .isDirectory)
        .appending(path: "cache.json", directoryHint: .notDirectory)

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    func load() throws -> CacheSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try HarvestClient.decoder.decode(CacheSnapshot.self, from: Data(contentsOf: fileURL))
    }

    func save(_ snapshot: CacheSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    func delete() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
