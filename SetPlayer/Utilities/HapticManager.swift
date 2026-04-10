import AppKit

enum HapticManager {
    static func play(_ pattern: Pattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(
            pattern.feedback,
            performanceTime: .default
        )
    }

    enum Pattern {
        case selection
        case playPause
        case navigation

        var feedback: NSHapticFeedbackManager.FeedbackPattern {
            switch self {
            case .selection: .generic
            case .playPause: .levelChange
            case .navigation: .alignment
            }
        }
    }
}
