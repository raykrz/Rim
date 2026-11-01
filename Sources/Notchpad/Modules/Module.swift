import SwiftUI

/// A tab inside the notch. Add a new module by conforming to this and listing it in `ModuleRegistry`.
protocol NotchModule {
    var id: String { get }
    var title: String { get }
    var systemImage: String { get }
    @MainActor func makeView() -> AnyView
}

enum ModuleRegistry {
    static let all: [any NotchModule] = [
        ClipboardModule(),
        ConvertModule(),
        PlaceholderModule(id: "shelf", title: "Shelf", systemImage: "tray.and.arrow.down", blurb: "Park files here while you move between apps."),
        PlaceholderModule(id: "devtools", title: "Dev tools", systemImage: "hammer", blurb: "JSON, Base64, UUID, JWT and more, applied to your clipboard."),
        PlaceholderModule(id: "focus", title: "Focus", systemImage: "timer", blurb: "Pomodoro timer and media controls."),
    ]

    static func module(id: String) -> (any NotchModule)? {
        all.first { $0.id == id }
    }
}

struct PlaceholderModule: NotchModule {
    let id: String
    let title: String
    let systemImage: String
    let blurb: String

    @MainActor func makeView() -> AnyView {
        AnyView(
            VStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 26)).foregroundStyle(.white.opacity(0.5))
                Text(title).font(.headline).foregroundStyle(.white)
                Text(blurb).font(.caption).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
                Text("Coming soon").font(.caption2).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.12))).foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}
