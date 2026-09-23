import Foundation

struct OAuthCallback: Equatable {
    let accessToken: String
    let expiresIn: TimeInterval
    let accountScope: AccountScope
}

enum AccountScope: Equatable {
    case account(Int)
    case allAccounts
}

enum OAuthCallbackError: Error, Equatable {
    case stateMismatch
    case authorizationFailed(String)
    case missingParameter(String)
    case unsupportedScope(String)
}

extension OAuthCallbackError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .stateMismatch:
            "The Harvest response does not match this connection attempt. Connect again."
        case .authorizationFailed(let reason):
            "Harvest did not authorize Speedscythe: \(reason)"
        case .missingParameter(let name):
            "The Harvest response has no \(name) value."
        case .unsupportedScope(let scope):
            "Harvest gave access to an unsupported scope: \(scope)"
        }
    }
}

enum OAuthCallbackParser {
    static func parse(_ url: URL, expectedState: String) throws -> OAuthCallback {
        let parameters = parameters(of: url)
        guard parameters["state"] == expectedState else {
            throw OAuthCallbackError.stateMismatch
        }
        if let error = parameters["error"] {
            throw OAuthCallbackError.authorizationFailed(parameters["error_description"] ?? error)
        }
        guard let accessToken = parameters["access_token"], !accessToken.isEmpty else {
            throw OAuthCallbackError.missingParameter("access_token")
        }
        guard let expiresIn = parameters["expires_in"].flatMap(TimeInterval.init) else {
            throw OAuthCallbackError.missingParameter("expires_in")
        }
        guard let scope = parameters["scope"] else {
            throw OAuthCallbackError.missingParameter("scope")
        }
        return OAuthCallback(accessToken: accessToken, expiresIn: expiresIn, accountScope: try accountScope(from: scope))
    }

    private static func accountScope(from scope: String) throws -> AccountScope {
        let entries = scope.split(whereSeparator: { $0 == " " || $0 == "+" })
        for entry in entries where entry.hasPrefix("harvest:") {
            if let accountID = Int(entry.dropFirst("harvest:".count)) {
                return .account(accountID)
            }
        }
        if entries.contains("harvest:all") || entries.contains("all") {
            return .allAccounts
        }
        throw OAuthCallbackError.unsupportedScope(scope)
    }

    private static func parameters(of url: URL) -> [String: String] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = components?.queryItems ?? []
        if let fragment = components?.percentEncodedFragment {
            items += URLComponents(string: "?" + fragment)?.queryItems ?? []
        }
        var parameters: [String: String] = [:]
        for item in items {
            parameters[item.name] = item.value
        }
        return parameters
    }
}
