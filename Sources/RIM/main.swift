import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared

    // Headless mode for testing the converter: RIM --convert <file> <output extension> [button title contains]
    let args = CommandLine.arguments
    if args.count >= 4, args[1] == "--convert" {
        ConvertCLI.run(path: args[2], ext: args[3], title: args.count > 4 ? args[4] : nil)
        app.run()
    }

    // Headless mode for the dev tools: RIM --devtool <id> <input>
    if args.count >= 3, args[1] == "--devtool" {
        guard let tool = DevTools.tool(id: args[2]) else { print("Unknown tool. Ids: " + DevTools.all.map(\.id).joined(separator: ", ")); exit(2) }
        do { print(try tool.run(args.count > 3 ? args[3] : "")) } catch { print("Error: \(error.localizedDescription)"); exit(1) }
        exit(0)
    }

    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
