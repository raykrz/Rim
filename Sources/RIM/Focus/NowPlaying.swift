import AppKit

/// Reads and controls Spotify or Music with AppleScript. macOS asks for permission the first time.
@MainActor
final class NowPlayingModel: ObservableObject {
    static let shared = NowPlayingModel()

    struct Track: Equatable {
        let app: String
        let title: String
        let artist: String
        let isPlaying: Bool
    }

    @Published private(set) var track: Track?
    @Published private(set) var permissionDenied: String?

    private static let players: [(name: String, bundleID: String)] = [
        ("Spotify", "com.spotify.client"),
        ("Music", "com.apple.Music"),
    ]

    private let queue = DispatchQueue(label: "rim.applescript")
    private var timer: Timer?

    func start() {
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func send(_ command: String) {
        guard let app = track?.app ?? runningPlayers().first else { return }
        queue.async { [weak self] in
            _ = Self.run("tell application \"\(app)\" to \(command)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Task { @MainActor in self?.refresh() } }
        }
    }

    private func runningPlayers() -> [String] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return Self.players.filter { running.contains($0.bundleID) }.map(\.name)
    }

    private func refresh() {
        let apps = runningPlayers()
        guard !apps.isEmpty else {
            track = nil
            return
        }
        queue.async {
            var best: Track?
            var denied: String?
            for app in apps {
                let script = """
                tell application "\(app)"
                    if player state is stopped then return "stopped||"
                    return (player state as text) & "|" & (name of current track) & "|" & (artist of current track)
                end tell
                """
                switch Self.run(script) {
                case .success(let text):
                    let parts = text.components(separatedBy: "|")
                    guard parts.count >= 3, parts[0] != "stopped" else { continue }
                    let track = Track(app: app, title: parts[1], artist: parts[2], isPlaying: parts[0] == "playing")
                    if best == nil || track.isPlaying { best = track }
                case .failure(let code):
                    if code == -1743 { denied = app }
                }
            }
            DispatchQueue.main.async {
                Task { @MainActor in
                    self.track = best
                    self.permissionDenied = best == nil ? denied : nil
                }
            }
        }
    }

    private nonisolated static func run(_ source: String) -> Result<String, ScriptFailure> {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return .failure(ScriptFailure(code: 0)) }
        let result = script.executeAndReturnError(&error)
        if let error { return .failure(ScriptFailure(code: error[NSAppleScript.errorNumber] as? Int ?? 0)) }
        return .success(result.stringValue ?? "")
    }

    struct ScriptFailure: Error, Equatable, ExpressibleByIntegerLiteral {
        let code: Int
        init(code: Int) { self.code = code }
        init(integerLiteral value: Int) { code = value }
        static func == (lhs: ScriptFailure, rhs: Int) -> Bool { lhs.code == rhs }
    }
}
