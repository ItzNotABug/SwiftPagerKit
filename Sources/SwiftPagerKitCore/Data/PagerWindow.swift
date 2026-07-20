struct PagerWindowDiff: Equatable {
    var toAttach: [Int]
    var toDetach: [Int]
}

enum PagerWindow {
    static func range(center: Int, count: Int, radius: Int) -> ClosedRange<Int>? {
        guard count > 0 else { return nil }

        let clampedCenter = min(max(center, 0), count - 1)
        let clampedRadius = min(max(0, radius), count - 1)
        let lowerBound = clampedCenter - min(clampedCenter, clampedRadius)
        let upperBound = clampedCenter + min(count - 1 - clampedCenter, clampedRadius)
        return lowerBound...upperBound
    }

    static func range(center: Int, count: Int, radius: Int, directionBias: Int) -> ClosedRange<Int>? {
        guard directionBias != 0 else {
            return range(center: center, count: count, radius: radius)
        }
        guard count > 0 else { return nil }

        let clampedRadius = min(max(0, radius), count - 1)
        guard clampedRadius > 0 else {
            let clampedCenter = min(max(center, 0), count - 1)
            return clampedCenter...clampedCenter
        }

        let clampedCenter = min(max(center, 0), count - 1)
        let desiredCount = desiredWindowCount(count: count, radius: clampedRadius)
        let desiredDistance = desiredCount - 1

        if directionBias > 0 {
            let forwardUpperBound = clampedCenter + min(count - 1 - clampedCenter, desiredDistance)
            let lowerBound = forwardUpperBound - min(forwardUpperBound, desiredDistance)
            return lowerBound...forwardUpperBound
        }

        let backwardLowerBound = clampedCenter - min(clampedCenter, desiredDistance)
        let upperBound = backwardLowerBound + min(count - 1 - backwardLowerBound, desiredDistance)
        return backwardLowerBound...upperBound
    }

    private static func desiredWindowCount(count: Int, radius: Int) -> Int {
        guard radius < count / 2 else { return count }
        return radius * 2 + 1
    }

    static func diff(attached: some Collection<Int>, desired: ClosedRange<Int>?) -> PagerWindowDiff {
        let attachedSet = Set(attached)
        let desiredSet = desired.map { Set($0) } ?? []

        return PagerWindowDiff(
            toAttach: desiredSet.subtracting(attachedSet).sorted(),
            toDetach: attachedSet.subtracting(desiredSet).sorted()
        )
    }
}
