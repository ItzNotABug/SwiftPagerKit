#if canImport(UIKit)
import Testing
@testable import SwiftPagerKitCore

@Suite
struct PagerDataSourceTests {
    @Test
    func dataSourceScansWhenNoIDIndexIsProvided() {
        var itemCalls: [Int] = []
        let dataSource = PagerDataSource<Int>(count: 5) { index in
            itemCalls.append(index)
            return PagerItem(
                index: index,
                element: index,
                id: AnyHashable(index),
                reuseType: nil
            )
        }

        #expect(dataSource.indexOfPage(id: AnyHashable(3)) == 3)
        #expect(itemCalls == [0, 1, 2, 3])
    }

    @Test
    func dataSourceUsesProvidedIDIndex() {
        var requestedIDs: [AnyHashable] = []
        var itemCalls: [Int] = []
        let dataSource = PagerDataSource<Int>(
            count: 100,
            item: { index in
                itemCalls.append(index)
                return PagerItem(
                    index: index,
                    element: index,
                    id: AnyHashable(index),
                    reuseType: nil
                )
            },
            indexOfID: { id in
                requestedIDs.append(id)
                return id.base as? Int
            }
        )

        #expect(dataSource.indexOfPage(id: AnyHashable(42)) == 42)
        #expect(requestedIDs == [AnyHashable(42)])
        #expect(itemCalls == [42])
    }

    @Test
    func dataSourceScansWhenProvidedIDIndexIsStale() {
        var itemCalls: [Int] = []
        let dataSource = PagerDataSource<Int>(
            count: 5,
            item: { index in
                itemCalls.append(index)
                return PagerItem(
                    index: index,
                    element: index,
                    id: AnyHashable(index),
                    reuseType: nil
                )
            },
            indexOfID: { _ in 1 }
        )

        #expect(dataSource.indexOfPage(id: AnyHashable(3)) == 3)
        #expect(itemCalls == [1, 0, 1, 2, 3])
    }

    @Test
    func dataSourceScansWhenNonAuthoritativeIDIndexMisses() {
        var itemCalls: [Int] = []
        let dataSource = PagerDataSource<Int>(
            count: 5,
            item: { index in
                itemCalls.append(index)
                return PagerItem(
                    index: index,
                    element: index,
                    id: AnyHashable(index),
                    reuseType: nil
                )
            },
            indexOfID: { _ in nil }
        )

        #expect(dataSource.indexOfPage(id: AnyHashable(3)) == 3)
        #expect(itemCalls == [0, 1, 2, 3])
    }

    @Test
    func dataSourceDoesNotScanWhenAuthoritativeIDIndexMisses() {
        var itemCalls: [Int] = []
        let dataSource = PagerDataSource<Int>(
            count: 5,
            item: { index in
                itemCalls.append(index)
                return PagerItem(
                    index: index,
                    element: index,
                    id: AnyHashable(index),
                    reuseType: nil
                )
            },
            indexOfID: { _ in nil },
            isIDIndexAuthoritative: true
        )

        #expect(dataSource.indexOfPage(id: AnyHashable(3)) == nil)
        #expect(itemCalls.isEmpty)
    }

    @Test
    func idIndexBuildsFullMapOnceUnderMemoryCap() {
        var idProviderCalls = 0
        let index = PagerIDIndex(data: Array(0..<100)) { offset, value in
            idProviderCalls += 1
            return AnyHashable(value + offset)
        }

        #expect(index.indexOfPage(id: AnyHashable(84)) == 42)
        #expect(idProviderCalls == 100)

        #expect(index.indexOfPage(id: AnyHashable(14)) == 7)
        #expect(idProviderCalls == 100)
    }

    @Test
    func idIndexAvoidsFullMapOverMemoryCap() {
        let count = PagerIDIndexDefaults.fullIndexLimit + 1
        var idProviderCalls = 0
        let index = PagerIDIndex(data: Array(0..<count)) { _, value in
            idProviderCalls += 1
            return AnyHashable(value)
        }

        #expect(index.indexOfPage(id: AnyHashable(42)) == 42)
        #expect(idProviderCalls == 43)

        #expect(index.indexOfPage(id: AnyHashable(42)) == 42)
        #expect(idProviderCalls == 44)
    }

    @Test
    func idIndexCachesMissesOverMemoryCap() {
        let count = PagerIDIndexDefaults.fullIndexLimit + 1
        var idProviderCalls = 0
        let index = PagerIDIndex(data: Array(0..<count)) { _, value in
            idProviderCalls += 1
            return AnyHashable(value)
        }

        #expect(index.indexOfPage(id: AnyHashable(-1)) == nil)
        #expect(idProviderCalls == count)

        #expect(index.indexOfPage(id: AnyHashable(-1)) == nil)
        #expect(idProviderCalls == count)
    }

    @Test
    func sharedLookupCacheRefreshesHitsBeforeEviction() {
        let cache = PagerIDLookupCache(limit: 2)
        cache.remember(id: AnyHashable(1), index: 10)
        cache.remember(id: AnyHashable(2), index: 20)

        #expect(cache.index(for: AnyHashable(1)) == 10)

        cache.remember(id: AnyHashable(3), index: 30)

        #expect(cache.index(for: AnyHashable(1)) == 10)
        #expect(cache.index(for: AnyHashable(2)) == nil)
        #expect(cache.index(for: AnyHashable(3)) == 30)
    }

    @Test
    func idIndexSharesValidatedHitsAcrossLargeDataSourceInstances() {
        let count = PagerIDIndexDefaults.fullIndexLimit + 1
        let sharedCache = PagerIDLookupCache()
        var idProviderCalls = 0

        let firstIndex = PagerIDIndex(data: Array(0..<count), idProvider: { _, value in
            idProviderCalls += 1
            return AnyHashable(value)
        }, sharedCache: sharedCache, assumesUniqueIDs: true)

        #expect(firstIndex.indexOfPage(id: AnyHashable(count - 1)) == count - 1)
        #expect(idProviderCalls == count)

        let callsAfterFirstLookup = idProviderCalls
        let secondIndex = PagerIDIndex(data: Array(0..<count), idProvider: { _, value in
            idProviderCalls += 1
            return AnyHashable(value)
        }, sharedCache: sharedCache, assumesUniqueIDs: true)

        #expect(secondIndex.indexOfPage(id: AnyHashable(count - 1)) == count - 1)
        #expect(idProviderCalls == callsAfterFirstLookup + 1)
    }

    @Test
    func idIndexFallsBackToScanWhenSharedHitIsStale() {
        let count = PagerIDIndexDefaults.fullIndexLimit + 1
        let sharedCache = PagerIDLookupCache()
        var idProviderCalls = 0

        let firstIndex = PagerIDIndex(data: Array(0..<count), idProvider: { _, value in
            idProviderCalls += 1
            return AnyHashable(value)
        }, sharedCache: sharedCache)

        #expect(firstIndex.indexOfPage(id: AnyHashable(42)) == 42)

        idProviderCalls = 0
        let shiftedData = Array(100_000..<(100_000 + count))
        let secondIndex = PagerIDIndex(data: shiftedData, idProvider: { _, value in
            idProviderCalls += 1
            return AnyHashable(value)
        }, sharedCache: sharedCache)

        #expect(secondIndex.indexOfPage(id: AnyHashable(42)) == nil)
        #expect(idProviderCalls == count + 1)
    }

    @Test
    func idIndexDoesNotUseSharedHitWhenEarlierDuplicateExists() {
        let sharedCache = PagerIDLookupCache()
        var idProviderCalls = 0

        let firstIndex = PagerIDIndex(data: [0, 2, 1, 3], idProvider: { _, value in
            idProviderCalls += 1
            return AnyHashable(value)
        }, sharedCache: sharedCache)

        #expect(firstIndex.indexOfPage(id: AnyHashable(1)) == 2)

        idProviderCalls = 0
        let secondIndex = PagerIDIndex(data: [0, 1, 1, 3], idProvider: { _, value in
            idProviderCalls += 1
            return AnyHashable(value)
        }, sharedCache: sharedCache)

        #expect(secondIndex.indexOfPage(id: AnyHashable(1)) == 1)
        #expect(idProviderCalls == 7)
    }
}
#endif
