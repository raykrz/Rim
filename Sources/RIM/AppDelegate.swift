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
        installEditMenu()

        // `RIM --pinned` starts with the notch held open, handy for screenshots and testing.
        // `--tab=<id>` picks the starting tab, `--shelf=<path>` preloads a file, `--tool=<id>` runs a dev tool on the clipboard, `--focus-start=<seconds>` starts the timer, `--dragging` shows the drop chooser.
        let args = CommandLine.arguments
        if let tab = args.first(where: { $0.hasPrefix("--tab=") }) {
            controller.state.selectedModule = String(tab.dropFirst("--tab=".count))
        }
        if let seconds = args.first(where: { $0.hasPrefix("--focus-start=") }).flatMap({ Int($0.dropFirst("--focus-start=".count)) }) {
            FocusModel.shared.setSeconds(seconds)
            FocusModel.shared.start()
        }
        if let tool = args.first(where: { $0.hasPrefix("--tool=") }).flatMap({ DevTools.tool(id: String($0.dropFirst("--tool=".count))) }) {
            DevToolsModel.shared.loadClipboardIfNew()
            DevToolsModel.shared.run(tool)
        }
        ShelfStore.shared.add(args.filter { $0.hasPrefix("--shelf=") }.map { URL(fileURLWithPath: String($0.dropFirst("--shelf=".count))) })
        if args.contains("--pinned") {
            controller.state.pinned = true
            controller.open()
            controller.state.isDragging = args.contains("--dragging")
        }
    }

    /// Without a main menu there are no ⌘X/⌘C/⌘V/⌘Z shortcuts in text fields. The menu bar stays hidden.
    private func installEditMenu() {
        let mainMenu = NSMenu()
        mainMenu.addItem(NSMenuItem())

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "RIM")

        let menu = NSMenu()
        let pin = NSMenuItem(title: "Pin open", action: #selector(togglePin(_:)), keyEquivalent: "")
        pin.target = self
        menu.addItem(pin)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit RIM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
