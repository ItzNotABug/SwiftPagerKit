#if canImport(UIKit)
import SwiftUI

@MainActor
private protocol AnyPagerReusePoolStorage: AnyObject {
    var limit: Int { get set }
    func removeAll()
}

/// A shared cache of reusable SwiftUI hosting controllers.
///
/// Use one pool across compatible pager instances when pages frequently leave
/// the live window. The pool retains hosts that already entered reuse until
/// `removeAll()` is called, the pool is released, or its `limit` evicts older
/// hosts. Tearing down a pager discards its active and retained pages instead of
/// moving them into this pool. An attached pager may also clear this pool during
/// a system memory warning.
@MainActor
public final class SwiftPagerReusePool {
    private var pools: [ObjectIdentifier: any AnyPagerReusePoolStorage] = [:]
    private var limitStorage: Int

    /// The maximum number of reusable hosts kept per hosted content type.
    ///
    /// Values are clamped to `SwiftPagerLimits.maximumReusePoolLimit`.
    public var limit: Int {
        get { limitStorage }
        set {
            limitStorage = SwiftPagerCachePolicy.clampReusePoolLimit(newValue)
            for pool in pools.values {
                pool.limit = limitStorage
            }
        }
    }

    /// Creates a shared reuse pool.
    ///
    /// - Parameter limit: Maximum cached reusable hosts per hosted content type.
    public init(limit: Int = SwiftPagerCachePolicy.balanced.reusePoolLimit) {
        self.limitStorage = SwiftPagerCachePolicy.clampReusePoolLimit(limit)
    }

    /// Discards every cached host currently retained by the pool.
    public func removeAll() {
        for pool in pools.values {
            pool.removeAll()
        }
    }

    func pool<Element, Content: View>() -> PagerReusePool<Element, Content> {
        let key = ObjectIdentifier(PagerHost<Element, Content>.self)
        if let pool = pools[key] as? PagerReusePool<Element, Content> {
            pool.limit = limit
            return pool
        }

        let pool = PagerReusePool<Element, Content>()
        pool.limit = limit
        pools[key] = pool
        return pool
    }
}

@MainActor
final class PagerReusePool<Element, Content: View> {
    var limit: Int = 5 {
        didSet { trimToLimit() }
    }

    private struct DefaultReuseType: Hashable {}

    private var pools: [AnyHashable: [PagerHost<Element, Content>]] = [:]
    private var poolOrder: [AnyHashable] = []
    private var pooledCount = 0
    private let defaultReuseType = AnyHashable(DefaultReuseType())

    func enqueue(_ host: PagerHost<Element, Content>) {
        guard limit > 0 else {
            host.discard()
            return
        }

        host.prepareForReuse()
        let key = host.reuseType ?? defaultReuseType
        var pool = pools[key, default: []]
        pool.append(host)
        pools[key] = pool
        poolOrder.append(key)
        pooledCount += 1
        trimToLimit()
    }

    func dequeue(reuseType: AnyHashable?) -> PagerHost<Element, Content>? {
        let key = reuseType ?? defaultReuseType
        guard var pool = pools[key], !pool.isEmpty else { return nil }
        let host = pool.removeLast()
        pooledCount -= 1
        if let orderIndex = poolOrder.lastIndex(of: key) {
            poolOrder.remove(at: orderIndex)
        }
        if pool.isEmpty {
            pools[key] = nil
        } else {
            pools[key] = pool
        }
        return host
    }

    func removeAll() {
        for pool in pools.values {
            for host in pool {
                host.discard()
            }
        }
        pools.removeAll()
        poolOrder.removeAll()
        pooledCount = 0
    }

    private func trimToLimit() {
        while pooledCount > limit, !poolOrder.isEmpty {
            let key = poolOrder.removeFirst()
            guard var pool = pools[key], !pool.isEmpty else { continue }
            let host = pool.removeFirst()
            pooledCount -= 1
            if pool.isEmpty {
                pools[key] = nil
            } else {
                pools[key] = pool
            }
            host.discard()
        }
    }
}

extension PagerReusePool: AnyPagerReusePoolStorage {}
#endif
