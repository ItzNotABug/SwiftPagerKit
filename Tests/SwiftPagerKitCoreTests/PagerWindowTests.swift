import Testing
@testable import SwiftPagerKitCore

@Suite
struct PagerWindowTests {
    @Test
    func rangeClampsAroundCenter() {
        #expect(PagerWindow.range(center: 5, count: 10, radius: 2) == 3...7)
        #expect(PagerWindow.range(center: 0, count: 10, radius: 2) == 0...2)
        #expect(PagerWindow.range(center: 9, count: 10, radius: 2) == 7...9)
        #expect(PagerWindow.range(center: 99, count: 10, radius: 1) == 8...9)
    }

    @Test
    func rangeReturnsNilForEmptyData() {
        #expect(PagerWindow.range(center: 0, count: 0, radius: 3) == nil)
    }

    @Test
    func rangeHandlesExtremeRadiusWithoutOverflow() {
        #expect(PagerWindow.range(center: 5, count: 10, radius: Int.max) == 0...9)
        #expect(PagerWindow.range(center: 5, count: 10, radius: Int.max, directionBias: 1) == 0...9)
        #expect(PagerWindow.range(center: 5, count: 10, radius: Int.max, directionBias: -1) == 0...9)
    }

    @Test
    func directionalRangeBiasesTowardScrollDirection() {
        #expect(PagerWindow.range(center: 5, count: 10, radius: 2, directionBias: 1) == 5...9)
        #expect(PagerWindow.range(center: 5, count: 10, radius: 2, directionBias: -1) == 1...5)
        #expect(PagerWindow.range(center: 5, count: 10, radius: 2, directionBias: 0) == 3...7)
    }

    @Test
    func directionalRangeFillsFromOppositeSideNearEdges() {
        #expect(PagerWindow.range(center: 8, count: 10, radius: 2, directionBias: 1) == 5...9)
        #expect(PagerWindow.range(center: 1, count: 10, radius: 2, directionBias: -1) == 0...4)
    }

    @Test
    func diffComputesAttachAndDetachSets() {
        let diff = PagerWindow.diff(attached: [1, 2, 3], desired: 2...4)
        #expect(diff.toAttach == [4])
        #expect(diff.toDetach == [1])
    }

    @Test
    func diffDetachesEverythingForNilRange() {
        let diff = PagerWindow.diff(attached: [1, 2, 3], desired: nil)
        #expect(diff.toAttach == [])
        #expect(diff.toDetach == [1, 2, 3])
    }
}
