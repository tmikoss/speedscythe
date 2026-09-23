import Foundation

struct SlotResolution: Equatable {
    let slots: [Int?]
    let recentSlots: [Int: Int]
}

enum SlotResolver {
    static func resolve(
        pinned: [Int: Int],
        slotCount: Int,
        recentOrder: [Int],
        previousRecentSlots: [Int: Int],
        activeProjects: Set<Int>
    ) -> SlotResolution {
        var slots = [Int?](repeating: nil, count: slotCount)
        var pinnedProjects = Set<Int>()
        for (index, projectID) in pinned.sorted(by: { $0.key < $1.key })
        where slots.indices.contains(index) && activeProjects.contains(projectID) && pinnedProjects.insert(projectID).inserted {
            slots[index] = projectID
        }

        let recentIndices = slots.indices.filter { slots[$0] == nil }
        let recent = Array(recentOrder.filter { activeProjects.contains($0) && !pinnedProjects.contains($0) }.prefix(recentIndices.count))

        var placed = Set<Int>()
        for (index, projectID) in previousRecentSlots.sorted(by: { $0.key < $1.key })
        where recentIndices.contains(index) && recent.contains(projectID) && !placed.contains(projectID) {
            slots[index] = projectID
            placed.insert(projectID)
        }

        var newcomers = recent.filter { !placed.contains($0) }.makeIterator()
        for index in recentIndices where slots[index] == nil {
            guard let projectID = newcomers.next() else { break }
            slots[index] = projectID
        }

        let recentSlots = Dictionary(uniqueKeysWithValues: recentIndices.compactMap { index in slots[index].map { (index, $0) } })
        return SlotResolution(slots: slots, recentSlots: recentSlots)
    }
}
