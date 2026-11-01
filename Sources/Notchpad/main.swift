import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared

    // Headless mode for testing the converter: Notchpad --convert <file> <output extension> [button title contains]
    let args = CommandLine.arguments
    if args.count >= 4, args[1] == "--convert" {
        ConvertCLI.run(path: args[2], ext: args[3], title: args.count > 4 ? args[4] : nil)
        app.run()
    }

    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
