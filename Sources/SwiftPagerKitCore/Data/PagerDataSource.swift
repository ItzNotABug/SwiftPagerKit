#if canImport(UIKit)
struct PagerItem<Element> {
    var index: Int
    var element: Element
    var id: AnyHashable
    var reuseType: AnyHashable?
}

struct PagerDataSource<Element> {
    var count: Int
    var item: (Int) -> PagerItem<Element>?
    private var indexOfID: ((AnyHashable) -> Int?)?
    private var isIDIndexAuthoritative: Bool

    init(
        count: Int,
        item: @escaping (Int) -> PagerItem<Element>?,
        indexOfID: ((AnyHashable) -> Int?)? = nil,
        isIDIndexAuthoritative: Bool = false
    ) {
        self.count = count
        self.item = item
        self.indexOfID = indexOfID
        self.isIDIndexAuthoritative = isIDIndexAuthoritative
    }

    static var empty: PagerDataSource<Element> {
        PagerDataSource(count: 0) { _ in nil }
    }

    var isEmpty: Bool {
        count == 0
    }

    func contains(_ index: Int) -> Bool {
        index >= 0 && index < count
    }

    func indexOfPage(id: AnyHashable) -> Int? {
        if let indexOfID {
            if let index = indexOfID(id) {
                if contains(index), item(index)?.id == id {
                    return index
                }
            } else if isIDIndexAuthoritative {
                return nil
            }
        }

        for index in 0..<count {
            if item(index)?.id == id {
                return index
            }
        }

        return nil
    }
}

enum PagerIDIndexDefaults {
    static let fullIndexLimit = 10_000
    static let lookupCacheLimit = 1_024
    static let sharedLookupCacheLimit = 4_096
}

final class PagerIDLookupCache {
    private var cachedLookupByID: [AnyHashable: Int] = [:]
    private var cachedLookupOrder: [AnyHashable] = []
    private let limit: Int

    init(limit: Int = PagerIDIndexDefaults.sharedLookupCacheLimit) {
        self.limit = max(0, limit)
    }

    func index(for id: AnyHashable) -> Int? {
        guard let index = cachedLookupByID[id] else { return nil }
        refresh(id: id)
        return index
    }

    func remember(id: AnyHashable, index: Int) {
        guard limit > 0 else { return }

        refresh(id: id)
        cachedLookupByID[id] = index

        while cachedLookupOrder.count > limit {
            let evictedID = cachedLookupOrder.removeFirst()
            cachedLookupByID[evictedID] = nil
        }
    }

    func remove(id: AnyHashable) {
        guard cachedLookupByID[id] != nil else { return }
        cachedLookupByID[id] = nil
        cachedLookupOrder.removeAll { $0 == id }
    }

    private func refresh(id: AnyHashable) {
        cachedLookupOrder.removeAll { $0 == id }
        cachedLookupOrder.append(id)
    }
}

final class PagerIDIndex<Element, DataCollection: RandomAccessCollection> where DataCollection.Element == Element {
    private let data: DataCollection
    private let idProvider: (Int, Element) -> AnyHashable
    private let sharedCache: PagerIDLookupCache?
    private let assumesUniqueIDs: Bool
    private var indexByID: [AnyHashable: Int]?
    private var cachedLookupByID: [AnyHashable: Int] = [:]
    private var cachedLookupOrder: [AnyHashable] = []
    private var cachedMissesByID: Set<AnyHashable> = []
    private var cachedMissOrder: [AnyHashable] = []

    init(
        data: DataCollection,
        idProvider: @escaping (Int, Element) -> AnyHashable,
        sharedCache: PagerIDLookupCache? = nil,
        assumesUniqueIDs: Bool = false
    ) {
        self.data = data
        self.idProvider = idProvider
        self.sharedCache = sharedCache
        self.assumesUniqueIDs = assumesUniqueIDs
    }

    func indexOfPage(id: AnyHashable) -> Int? {
        if let sharedIndex = sharedCache?.index(for: id) {
            if itemID(at: sharedIndex) == id,
               assumesUniqueIDs || !containsEarlierID(id, before: sharedIndex) {
                return sharedIndex
            }
            sharedCache?.remove(id: id)
        }

        if data.count <= PagerIDIndexDefaults.fullIndexLimit {
            if let indexByID {
                return rememberSharedLookup(id: id, index: indexByID[id])
            }

            let indexByID = buildFullIndex()
            self.indexByID = indexByID
            return rememberSharedLookup(id: id, index: indexByID[id])
        }

        if let cachedIndex = cachedLookupByID[id] {
            if itemID(at: cachedIndex) == id {
                refreshLookup(id: id)
                sharedCache?.remember(id: id, index: cachedIndex)
                return cachedIndex
            }
            cachedLookupByID[id] = nil
            cachedLookupOrder.removeAll { $0 == id }
        }
        if cachedMissesByID.contains(id) {
            return nil
        }

        guard let index = scanForID(id) else {
            rememberMiss(id: id)
            return nil
        }
        rememberLookup(id: id, index: index)
        sharedCache?.remember(id: id, index: index)
        return index
    }

    private func rememberSharedLookup(id: AnyHashable, index: Int?) -> Int? {
        if let index {
            sharedCache?.remember(id: id, index: index)
        }
        return index
    }

    private func buildFullIndex() -> [AnyHashable: Int] {
        var indexByID: [AnyHashable: Int] = [:]
        indexByID.reserveCapacity(data.count)

        var offset = 0
        var collectionIndex = data.startIndex
        while collectionIndex != data.endIndex {
            let id = idProvider(offset, data[collectionIndex])
            if indexByID[id] == nil {
                indexByID[id] = offset
            }
            data.formIndex(after: &collectionIndex)
            offset += 1
        }

        return indexByID
    }

    private func scanForID(_ targetID: AnyHashable) -> Int? {
        var offset = 0
        var collectionIndex = data.startIndex
        while collectionIndex != data.endIndex {
            let id = idProvider(offset, data[collectionIndex])
            if id == targetID {
                return offset
            }
            data.formIndex(after: &collectionIndex)
            offset += 1
        }
        return nil
    }

    private func itemID(at offset: Int) -> AnyHashable? {
        guard offset >= 0, offset < data.count else { return nil }
        let collectionIndex = data.index(data.startIndex, offsetBy: offset)
        return idProvider(offset, data[collectionIndex])
    }

    private func containsEarlierID(_ targetID: AnyHashable, before targetOffset: Int) -> Bool {
        guard targetOffset > 0 else { return false }

        var offset = 0
        var collectionIndex = data.startIndex
        while collectionIndex != data.endIndex && offset < targetOffset {
            if idProvider(offset, data[collectionIndex]) == targetID {
                return true
            }
            data.formIndex(after: &collectionIndex)
            offset += 1
        }
        return false
    }

    private func rememberLookup(id: AnyHashable, index: Int) {
        refreshLookup(id: id)
        cachedLookupByID[id] = index
        cachedMissesByID.remove(id)
        cachedMissOrder.removeAll { $0 == id }

        while cachedLookupOrder.count > PagerIDIndexDefaults.lookupCacheLimit {
            let evictedID = cachedLookupOrder.removeFirst()
            cachedLookupByID[evictedID] = nil
        }
    }

    private func refreshLookup(id: AnyHashable) {
        cachedLookupOrder.removeAll { $0 == id }
        cachedLookupOrder.append(id)
    }

    private func rememberMiss(id: AnyHashable) {
        if cachedMissesByID.insert(id).inserted {
            cachedMissOrder.append(id)
        }

        while cachedMissOrder.count > PagerIDIndexDefaults.lookupCacheLimit {
            let evictedID = cachedMissOrder.removeFirst()
            cachedMissesByID.remove(evictedID)
        }
    }
}
#endif
