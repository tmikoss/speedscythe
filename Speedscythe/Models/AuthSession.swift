import Foundation

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let expiresAt: Date
    let accountID: Int
}
