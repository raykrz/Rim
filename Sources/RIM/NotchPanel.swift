import AppKit

/// Borderless, transparent window that floats above the menu bar.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    var onEscape: (() -> Void)?
    var onSelectTab: ((Int) -> Void)?

    /// Esc closes the notch.
    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    /// ⌘1 to ⌘5 jump to a tab while the notch has keyboard focus.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let digit = event.charactersIgnoringModifiers.flatMap({ Int($0) }), (1...9).contains(digit) {
            onSelectTab?(digit - 1)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
