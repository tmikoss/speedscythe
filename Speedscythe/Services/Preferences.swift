import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    static let slotRange = 4...9

    var slotCount: Int {
        didSet { defaults.set(slotCount, forKey: Keys.slotCount) }
    }

    var continueToday: Bool {
        didSet { defaults.set(continueToday, forKey: Keys.continueToday) }
    }

    var pinnedSlots: [Int: Int] {
        didSet { defaults.set(Self.stored(pinnedSlots), forKey: Keys.pinnedSlots) }
    }

    var taskOrders: [Int: [Int]] {
        didSet { defaults.set(Self.stored(taskOrders), forKey: Keys.taskOrders) }
    }

    @ObservationIgnored var recentSlotAssignments: [Int: Int] {
        didSet { defaults.set(Self.stored(recentSlotAssignments), forKey: Keys.recentSlotAssignments) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedSlotCount = defaults.object(forKey: Keys.slotCount) as? Int ?? 6
        slotCount = min(max(storedSlotCount, Self.slotRange.lowerBound), Self.slotRange.upperBound)
        continueToday = defaults.object(forKey: Keys.continueToday) as? Bool ?? true
        pinnedSlots = Self.intKeyed(defaults.dictionary(forKey: Keys.pinnedSlots))
        taskOrders = Self.intKeyed(defaults.dictionary(forKey: Keys.taskOrders))
        recentSlotAssignments = Self.intKeyed(defaults.dictionary(forKey: Keys.recentSlotAssignments))
    }

    private static func stored<Value>(_ values: [Int: Value]) -> [String: Value] {
        Dictionary(uniqueKeysWithValues: values.map { (String($0.key), $0.value) })
    }

    private static func intKeyed<Value>(_ stored: [String: Any]?) -> [Int: Value] {
        let stored = stored as? [String: Value] ?? [:]
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Int(key).map { ($0, value) } })
    }

    private enum Keys {
        static let slotCount = "slotCount"
        static let continueToday = "continueToday"
        static let pinnedSlots = "pinnedSlots"
        static let taskOrders = "taskOrders"
        static let recentSlotAssignments = "recentSlotAssignments"
    }
}
