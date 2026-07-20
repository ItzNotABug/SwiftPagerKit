import SwiftPagerKit

extension SwiftPagerScrollPhase {
    var title: String {
        switch self {
        case .idle:
            "Idle"
        case .dragging:
            "Drag"
        case .decelerating:
            "Decel"
        case .animating:
            "Anim"
        }
    }
}

extension SwiftPagerBoundary {
    var title: String {
        switch self {
        case .beginning:
            "start"
        case .end:
            "end"
        }
    }
}
