import Foundation

/// Files parked on the shelf. These are references to the originals, not copies, and live in memory only.
@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    @Published private(set) var items: [URL] = []

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(url) {
            items.insert(url, at: 0)
        }
    }

    func remove(_ url: URL) {
        items.removeAll { $0 == url }
    }

    func clear() {
        items.removeAll()
    }

    /// Drops entries whose files were moved or deleted since they were parked.
    func prune() {
        items.removeAll { !FileManager.default.fileExists(atPath: $0.path) }
    }
}
