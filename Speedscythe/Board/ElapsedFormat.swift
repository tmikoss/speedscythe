import Foundation

enum ElapsedFormat {
    static func hoursMinutes(_ interval: TimeInterval) -> String {
        let minutes = Int(max(interval, 0)) / 60
        return "\(minutes / 60):\(twoDigits(minutes % 60))"
    }

    static func hoursMinutesSeconds(_ interval: TimeInterval) -> String {
        let seconds = Int(max(interval, 0))
        return "\(seconds / 3600):\(twoDigits(seconds / 60 % 60)):\(twoDigits(seconds % 60))"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
