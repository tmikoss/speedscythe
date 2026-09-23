import Foundation

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let expiresAt: Date
    let accountID: Int

    func expiresSoon(at date: Date) -> Bool {
        expiresAt.timeIntervalSince(date) < 24 * 3600
    }
}
