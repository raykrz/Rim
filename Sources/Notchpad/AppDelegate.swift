import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController()
        controller.start()
        self.controller = controller
        ClipboardStore.shared.start()
        installStatusItem()

        // `Notchpad --pinned` starts with the notch held open, handy for screenshots and testing.
        if CommandLine.arguments.contains("--pinned") {
            controller.state.pinned = true
            controller.open()
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Notchpad")

        let menu = NSMenu()
        let pin = NSMenuItem(title: "Pin open", action: #selector(togglePin(_:)), keyEquivalent: "")
        pin.target = self
        menu.addItem(pin)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Notchpad", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        guard let state = controller?.state else { return }
        state.pinned.toggle()
        sender.state = state.pinned ? .on : .off
        if state.pinned { controller?.open() }
    }
}
