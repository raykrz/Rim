import AppKit

/// A countdown timer that keeps running while the notch is closed.
@MainActor
final class FocusModel: ObservableObject {
    static let shared = FocusModel()

    @Published private(set) var duration: TimeInterval = 25 * 60
    @Published private(set) var remaining: TimeInterval = 25 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var completed = false
    @Published private(set) var sessionsToday = 0
    @Published var label = ""

    /// Called when the countdown reaches zero, so the notch can open and announce it.
    var onFinish: (() -> Void)?

    private var endDate: Date?
    private var ticker: Timer?

    init() {
        sessionsToday = UserDefaults.standard.integer(forKey: Self.sessionsKey())
    }

    var progress: Double {
        duration > 0 ? min(1, max(0, 1 - remaining / duration)) : 0
    }

    /// Shown in the collapsed notch: running, paused part-way, or finished and not yet dismissed.
    var isActive: Bool {
        isRunning || completed || remaining < duration
    }

    func setMinutes(_ minutes: Int) {
        guard !isRunning else { return }
        duration = TimeInterval(max(1, min(180, minutes)) * 60)
        remaining = duration
        completed = false
    }

    /// For tests and screenshots, where a few seconds is more useful than a few minutes.
    func setSeconds(_ seconds: Int) {
        duration = TimeInterval(max(1, seconds))
        remaining = duration
        completed = false
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        if completed || remaining <= 0 { remaining = duration }
        completed = false
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func pause() {
        guard isRunning else { return }
        remaining = max(0, endDate?.timeIntervalSinceNow ?? remaining)
        stopTicker()
    }

    func reset() {
        stopTicker()
        remaining = duration
        completed = false
    }

    private func tick() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 { finish() }
    }

    private func finish() {
        stopTicker()
        completed = true
        sessionsToday += 1
        UserDefaults.standard.set(sessionsToday, forKey: Self.sessionsKey())
        NSSound(named: "Glass")?.play()
        onFinish?()
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        isRunning = false
        endDate = nil
    }

    private static func sessionsKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "focusSessions." + formatter.string(from: Date())
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
