import AppKit

enum Haptics {
    /// A light trackpad tap. Does nothing when no finger is on the trackpad.
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
