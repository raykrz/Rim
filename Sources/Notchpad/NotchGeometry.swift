import AppKit

/// Size and position of the notch (or a stand-in pill on Macs without one).
struct NotchGeometry {
    static let openSize = CGSize(width: 620, height: 230)
    private static let fallbackPill = CGSize(width: 190, height: 24)

    let screen: NSScreen
    let hasNotch: Bool
    let closedSize: CGSize

    init(screen: NSScreen) {
        self.screen = screen
        let inset = screen.safeAreaInsets.top
        if inset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            hasNotch = true
            closedSize = CGSize(width: screen.frame.width - left.width - right.width, height: inset)
        } else {
            hasNotch = false
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            closedSize = CGSize(width: Self.fallbackPill.width, height: max(menuBar, Self.fallbackPill.height))
        }
    }

    /// A rect of `size` flush with the top edge, centered on the screen (screen coordinates).
    func rect(size: CGSize) -> NSRect {
        NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    var panelFrame: NSRect { rect(size: Self.openSize) }
}
