import AppKit
import SwiftUI

/// Owns the panel and decides when the notch opens and closes based on the mouse position.
@MainActor
final class NotchController {
    let state = NotchState()

    private let panel = NotchPanel()
    private var geometry: NotchGeometry
    private var monitors: [Any] = []
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?

    private let openDelay: TimeInterval = 0.15
    private let closeDelay: TimeInterval = 0.25

    init() {
        geometry = NotchGeometry(screen: Self.targetScreen())
    }

    func start() {
        applyGeometry()
        panel.contentView = NSHostingView(rootView: NotchRootView(state: state))
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.mouseChanged() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            Task { @MainActor in self?.mouseChanged() }
            return event
        }
        monitors = [global, local].compactMap { $0 }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyGeometry() }
        }
    }

    func open() {
        cancelPending()
        guard !state.isOpen else { return }
        panel.ignoresMouseEvents = false
        state.isOpen = true
    }

    func close() {
        cancelPending()
        guard state.isOpen, !state.pinned else { return }
        state.isOpen = false
        panel.ignoresMouseEvents = true
    }

    // MARK: - Hover logic

    private func mouseChanged() {
        let inside = hoverRect.contains(NSEvent.mouseLocation)
        if inside {
            closeWork?.cancel()
            closeWork = nil
            if !state.isOpen, openWork == nil {
                schedule(\.openWork, after: openDelay) { [weak self] in
                    guard let self, self.hoverRect.contains(NSEvent.mouseLocation) else { return }
                    self.open()
                }
            }
        } else {
            openWork?.cancel()
            openWork = nil
            if state.isOpen, !state.pinned, closeWork == nil {
                schedule(\.closeWork, after: closeDelay) { [weak self] in
                    guard let self, !self.hoverRect.contains(NSEvent.mouseLocation) else { return }
                    self.close()
                }
            }
        }
    }

    /// The area that counts as "hovering the notch". NSRect.contains excludes the top edge, so extend upward.
    private var hoverRect: NSRect {
        let size = state.isOpen ? NotchGeometry.openSize : state.closedSize
        var rect = geometry.rect(size: size).insetBy(dx: -10, dy: 0)
        rect.size.height += 4
        rect.origin.y -= state.isOpen ? 8 : 0
        rect.size.height += state.isOpen ? 8 : 0
        return rect
    }

    private func schedule(_ slot: ReferenceWritableKeyPath<NotchController, DispatchWorkItem?>, after delay: TimeInterval, _ block: @escaping () -> Void) {
        let work = DispatchWorkItem { [weak self] in
            self?[keyPath: slot] = nil
            block()
        }
        self[keyPath: slot] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPending() {
        openWork?.cancel(); openWork = nil
        closeWork?.cancel(); closeWork = nil
    }

    // MARK: - Screen

    private func applyGeometry() {
        geometry = NotchGeometry(screen: Self.targetScreen())
        state.closedSize = geometry.closedSize
        state.hasNotch = geometry.hasNotch
        panel.setFrame(geometry.panelFrame, display: true)
    }

    /// Prefers the built-in display (the one with a notch), falling back to the main screen.
    private static func targetScreen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}
