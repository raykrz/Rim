import SwiftUI

struct ClipboardModule: NotchModule {
    let id = "clipboard"
    let title = "Clipboard"
    let systemImage = "doc.on.clipboard"

    @MainActor func makeView() -> AnyView { AnyView(ClipboardView()) }
}

private struct ClipboardView: View {
    @ObservedObject private var store = ClipboardStore.shared
    @State private var copiedID: UUID?
    @State private var revealedID: UUID?

    var body: some View {
        if store.items.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard").font(.system(size: 24)).foregroundStyle(.white.opacity(0.4))
                Text("Copy something and it shows up here").font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 4) {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(store.items) { item in
                            row(item)
                        }
                    }
                }
                HStack {
                    Text("History stays in memory only").font(.caption2).foregroundStyle(.white.opacity(0.35))
                    Spacer()
                    Button("Clear") { store.clear() }
                        .buttonStyle(.plain).font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        let isSecret = item.kind == .secret
        let revealed = revealedID == item.id
        return HStack(spacing: 8) {
            Button {
                store.copy(item)
                copiedID = item.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if copiedID == item.id { copiedID = nil }
                }
            } label: {
                HStack(spacing: 8) {
                    if item.kind == .file, let url = item.fileURLs.first {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 16, height: 16)
                    } else {
                        Image(systemName: icon(item.kind)).frame(width: 16).foregroundStyle(tint(item.kind))
                    }
                    Text(isSecret && revealed ? item.text : item.preview)
                        .font(item.kind == .code || isSecret ? .system(size: 12, design: .monospaced) : .system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(copiedID == item.id ? "Copied" : label(item.kind))
                        .font(.caption2).foregroundStyle(copiedID == item.id ? Color.green : .white.opacity(0.4))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSecret {
                Button {
                    revealedID = revealed ? nil : item.id
                    if !revealed {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            if revealedID == item.id { revealedID = nil }
                        }
                    }
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye").foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Reveal for 5 seconds")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.07)))
        .contextMenu {
            if item.kind == .file {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(item.fileURLs) }
            }
            Button("Remove") { store.remove(item) }
        }
    }

    private func icon(_ kind: ClipItem.Kind) -> String {
        switch kind {
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .link: return "link"
        case .secret: return "key.fill"
        case .file: return "doc"
        }
    }

    private func tint(_ kind: ClipItem.Kind) -> Color {
        switch kind {
        case .text: return .white.opacity(0.6)
        case .code: return .purple
        case .link: return .blue
        case .secret: return .orange
        case .file: return .white.opacity(0.6)
        }
    }

    private func label(_ kind: ClipItem.Kind) -> String {
        switch kind {
        case .text: return "text"
        case .code: return "code"
        case .link: return "link"
        case .secret: return "secret · wiped in 60s"
        case .file: return "file"
        }
    }
}
