import XCTest
@testable import Speedscythe

final class SlotResolverTests: XCTestCase {
    private let allProjects: Set<Int> = [1, 2, 3, 4, 5, 6, 7, 8, 9]

    func testPinnedProjectsKeepTheirSlotsAndRecentsFillTheRest() {
        let result = resolve(pinned: [0: 5, 2: 3], slotCount: 4, recentOrder: [1, 2, 3, 4])

        XCTAssertEqual(result.slots, [5, 1, 3, 2])
        XCTAssertEqual(result.recentSlots, [1: 1, 3: 2])
    }

    func testPinsOutsideSlotCountAreIgnored() {
        let result = resolve(pinned: [0: 1, 1: 2, 3: 4], slotCount: 3, recentOrder: [5, 6])

        XCTAssertEqual(result.slots, [1, 2, 5])
        XCTAssertEqual(result.recentSlots, [2: 5])
    }

    func testNewcomerReplacesLeastRecentAtSameIndex() {
        let result = resolve(slotCount: 3, recentOrder: [4, 1, 2], previousRecentSlots: [0: 1, 1: 2, 2: 3])

        XCTAssertEqual(result.slots, [1, 2, 4])
    }

    func testRecencyChangesAloneKeepNumbers() {
        let result = resolve(slotCount: 3, recentOrder: [3, 1, 2], previousRecentSlots: [0: 1, 1: 2, 2: 3])

        XCTAssertEqual(result.slots, [1, 2, 3])
    }

    func testOutputIsStableWhenNothingChanges() {
        let first = resolve(pinned: [1: 7], slotCount: 4, recentOrder: [3, 1, 2, 5])
        let second = resolve(pinned: [1: 7], slotCount: 4, recentOrder: [3, 1, 2, 5], previousRecentSlots: first.recentSlots)

        XCTAssertEqual(first, second)
    }

    func testArchivedPinnedProjectLeavesSlotToRecents() {
        let result = resolve(pinned: [0: 9, 1: 1], slotCount: 3, recentOrder: [2, 3], activeProjects: [1, 2, 3])

        XCTAssertEqual(result.slots, [2, 1, 3])
    }

    func testPinnedProjectIsNotRepeatedAsRecent() {
        let result = resolve(pinned: [0: 2], slotCount: 3, recentOrder: [2, 1, 3])

        XCTAssertEqual(result.slots, [2, 1, 3])
    }

    func testProjectPinnedTwiceKeepsOnlyTheLowestSlot() {
        let result = resolve(pinned: [0: 1, 2: 1], slotCount: 3, recentOrder: [2, 3])

        XCTAssertEqual(result.slots, [1, 2, 3])
    }

    func testFewerProjectsThanSlotsLeaveTrailingSlotsEmpty() {
        let result = resolve(slotCount: 5, recentOrder: [1, 2])

        XCTAssertEqual(result.slots, [1, 2, nil, nil, nil])
        XCTAssertEqual(result.recentSlots, [0: 1, 1: 2])
    }

    func testShrinkingSlotCountDropsOutOfRangeSlots() {
        let result = resolve(slotCount: 2, recentOrder: [4, 3, 2, 1], previousRecentSlots: [0: 1, 1: 2, 2: 3, 3: 4])

        XCTAssertEqual(result.slots, [4, 3])
    }

    func testGrowingSlotCountKeepsExistingNumbers() {
        let result = resolve(slotCount: 4, recentOrder: [3, 4, 1, 2], previousRecentSlots: [0: 1, 1: 2])

        XCTAssertEqual(result.slots, [1, 2, 3, 4])
    }

    func testPinningASlotMovesOnlyTheDisplacedRecentProject() {
        let result = resolve(pinned: [0: 9], slotCount: 3, recentOrder: [1, 2, 3], previousRecentSlots: [0: 1, 1: 2, 2: 3])

        XCTAssertEqual(result.slots, [9, 2, 1])
    }

    private func resolve(
        pinned: [Int: Int] = [:],
        slotCount: Int,
        recentOrder: [Int],
        previousRecentSlots: [Int: Int] = [:],
        activeProjects: Set<Int>? = nil
    ) -> SlotResolution {
        SlotResolver.resolve(
            pinned: pinned,
            slotCount: slotCount,
            recentOrder: recentOrder,
            previousRecentSlots: previousRecentSlots,
            activeProjects: activeProjects ?? allProjects
        )
    }
}
