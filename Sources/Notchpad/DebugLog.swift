import Foundation

/// Opt-in diagnostics. Run `Notchpad --debug` and read ~/Library/Logs/Notchpad.log.
/// Clipboard contents are never written, only pasteboard types and counts.
enum DebugLog {
    static let enabled = CommandLine.arguments.contains("--debug")

    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Notchpad.log")

    static func write(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message())\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
