import Foundation

enum Preferences {
    static var continueToday: Bool {
        UserDefaults.standard.object(forKey: "continueToday") as? Bool ?? true
    }
}
