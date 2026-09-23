import Foundation

enum HarvestOAuth {
    static let clientID = infoValue("HarvestClientID")
    static let redirectURI = URL(string: infoValue("HarvestRedirectURI"))!
    static let userAgent = infoValue("HarvestUserAgent")

    private static func infoValue(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            fatalError("Info.plist has no value for \(key). Set the build setting in project.yml.")
        }
        return value
    }
}
