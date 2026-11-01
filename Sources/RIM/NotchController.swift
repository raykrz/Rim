import AppKit
import SwiftUI

/// Owns the panel and decides when the notch opens and closes based on the mouse position.
@MainActor
final class NotchController {
    let state = NotchState.shared

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
        FocusModel.shared.onFinish = { [weak self] in self?.announceFocusFinished() }
        applyGeometry()
        panel.contentView = NSHostingView(rootView: NotchRootView(state: state))
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event.type) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event.type) }
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
        state.isDragging = isDraggingFiles
        state.isOpen = true
    }

    /// True while the user is mid-drag with files from Finder or another app.
    private var isDraggingFiles: Bool {
        NSEvent.pressedMouseButtons & 1 != 0
            && NSPasteboard(name: .drag).canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    func close() {
        cancelPending()
        guard state.isOpen, !state.pinned else { return }
        state.isOpen = false
        state.isDragging = false
        panel.ignoresMouseEvents = true
    }

    /// Pops the notch open on the Focus tab when the timer ends, then tucks it away unless you're using it.
    private func announceFocusFinished() {
        state.selectedModule = "focus"
        open()
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, !self.hoverRect.contains(NSEvent.mouseLocation) else { return }
            self.close()
        }
    }

    // MARK: - Hover logic

    private var dragPoll: Timer?

    private func handle(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            startDragPolling()
        case .leftMouseUp:
            // Let a drop land before the file chooser goes away.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, NSEvent.pressedMouseButtons & 1 == 0 else { return }
                self.state.isDragging = false
            }
            mouseChanged()
        default:
            mouseChanged()
        }
    }

    /// While a button is held, macOS doesn't send other apps' drag events during a drag session,
    /// so follow the pointer with a timer until the button is released.
    private func startDragPolling() {
        guard dragPoll == nil else { return }
        dragPoll = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { return }
                if NSEvent.pressedMouseButtons & 1 == 0 {
                    timer.invalidate()
                    self.dragPoll = nil
                }
                self.mouseChanged()
            }
        }
    }

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
            if state.isOpen, !state.pinned, closeWork == nil, NSEvent.pressedMouseButtons & 1 == 0 {
                schedule(\.closeWork, after: closeDelay) { [weak self] in
                    guard let self, !self.hoverRect.contains(NSEvent.mouseLocation),
                          NSEvent.pressedMouseButtons & 1 == 0 else { return }
                    self.close()
                }
            }
        }
    }

    /// The area that counts as "hovering the notch". NSRect.contains excludes the top edge, so extend upward.
    private var hoverRect: NSRect {
        let size = state.isOpen ? NotchGeometry.openSize : state.collapsedSize
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
