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
        // `--tab=<id>` picks the starting tab, `--shelf=<path>` preloads a file, `--dragging` shows the drop chooser.
        let args = CommandLine.arguments
        if let tab = args.first(where: { $0.hasPrefix("--tab=") }) {
            controller.state.selectedModule = String(tab.dropFirst("--tab=".count))
        }
        ShelfStore.shared.add(args.filter { $0.hasPrefix("--shelf=") }.map { URL(fileURLWithPath: String($0.dropFirst("--shelf=".count))) })
        if args.contains("--pinned") {
            controller.state.pinned = true
            controller.open()
            controller.state.isDragging = args.contains("--dragging")
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
