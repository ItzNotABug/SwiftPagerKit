import CoreGraphics
import Testing
@testable import SwiftPagerKitCore

@Suite
struct PagerConfigurationTests {
    @Test
    func clampsNegativeWindowValues() {
        let configuration = SwiftPagerConfiguration(
            pageSpacing: -4,
            preloadDistance: -1,
            retentionDistance: -2,
            reusePoolLimit: -3
        )

        #expect(configuration.pageSpacing == CGFloat(0))
        #expect(configuration.preloadDistance == 0)
        #expect(configuration.retentionDistance == 0)
        #expect(configuration.reusePoolLimit == 0)
    }

    @Test
    func retentionDistanceCannotBeSmallerThanPreloadDistance() {
        let configuration = SwiftPagerConfiguration(preloadDistance: 3, retentionDistance: 1)

        #expect(configuration.preloadDistance == 3)
        #expect(configuration.retentionDistance == 3)
    }

    @Test
    func cachePolicyClampsValues() {
        let policy = SwiftPagerCachePolicy(preloadDistance: -1, retentionDistance: -2, reusePoolLimit: -3)

        #expect(policy.preloadDistance == 0)
        #expect(policy.retentionDistance == 0)
        #expect(policy.reusePoolLimit == 0)
    }

    @Test
    func cachePolicyRetentionDistanceCannotBeSmallerThanPreloadDistance() {
        let policy = SwiftPagerCachePolicy(preloadDistance: 3, retentionDistance: 1, reusePoolLimit: 2)

        #expect(policy.preloadDistance == 3)
        #expect(policy.retentionDistance == 3)
        #expect(policy.reusePoolLimit == 2)
    }

    @Test
    func configurationCapsExtremeCacheBudgets() {
        var configuration = SwiftPagerConfiguration(
            preloadDistance: Int.max,
            retentionDistance: Int.max,
            reusePoolLimit: Int.max
        )

        #expect(configuration.preloadDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(configuration.retentionDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(configuration.reusePoolLimit == SwiftPagerLimits.maximumReusePoolLimit)

        configuration.preloadDistance = Int.max
        configuration.retentionDistance = Int.max
        configuration.reusePoolLimit = Int.max

        #expect(configuration.preloadDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(configuration.retentionDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(configuration.reusePoolLimit == SwiftPagerLimits.maximumReusePoolLimit)
    }

    @Test
    func cachePolicyCapsExtremeBudgets() {
        let policy = SwiftPagerCachePolicy(
            preloadDistance: Int.max,
            retentionDistance: Int.max,
            reusePoolLimit: Int.max
        )

        #expect(policy.preloadDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(policy.retentionDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(policy.reusePoolLimit == SwiftPagerLimits.maximumReusePoolLimit)
    }

    @Test
    func cachePolicyPresetsExposeExpectedBudgets() {
        #expect(SwiftPagerCachePolicy.minimal == SwiftPagerCachePolicy(preloadDistance: 0, retentionDistance: 0, reusePoolLimit: 0))
        #expect(SwiftPagerCachePolicy.balanced == SwiftPagerCachePolicy(preloadDistance: 1, retentionDistance: 2, reusePoolLimit: 5))
        #expect(SwiftPagerCachePolicy.performance == SwiftPagerCachePolicy(preloadDistance: 2, retentionDistance: 4, reusePoolLimit: 10))
    }

    @Test
    func configurationCanBeCreatedFromCachePolicy() {
        let configuration = SwiftPagerConfiguration(cachePolicy: .performance)

        #expect(configuration.preloadDistance == 2)
        #expect(configuration.retentionDistance == 4)
        #expect(configuration.reusePoolLimit == 10)
    }

#if canImport(UIKit)
    @MainActor
    @Test
    func sharedReusePoolLimitClampsNegativeValues() {
        let pool = SwiftPagerReusePool(limit: -1)

        #expect(pool.limit == 0)

        pool.limit = -2

        #expect(pool.limit == 0)
    }

    @MainActor
    @Test
    func sharedReusePoolLimitCapsExtremeValues() {
        let pool = SwiftPagerReusePool(limit: Int.max)

        #expect(pool.limit == SwiftPagerLimits.maximumReusePoolLimit)

        pool.limit = Int.max

        #expect(pool.limit == SwiftPagerLimits.maximumReusePoolLimit)
    }
#endif

    @Test
    func contentUpdatePolicyDefaultsToIdentity() {
        let configuration = SwiftPagerConfiguration()

        #expect(configuration.contentUpdatePolicy == .identity)
        #expect(configuration.contentRefreshToken == nil)
    }

    @Test
    func stateRestorationPolicyDefaultsToPreserve() {
        let configuration = SwiftPagerConfiguration()

        #expect(configuration.stateRestorationPolicy == .preserve)
    }
}
