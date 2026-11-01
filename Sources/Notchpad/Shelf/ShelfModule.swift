import SwiftUI

struct ShelfModule: NotchModule {
    let id = "shelf"
    let title = "Shelf"
    let systemImage = "tray.and.arrow.down"

    @MainActor func makeView() -> AnyView { AnyView(ShelfView()) }
}

private struct ShelfView: View {
    @ObservedObject private var store = ShelfStore.shared
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 6) {
            if store.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 26)).foregroundStyle(.white.opacity(0.5))
                    Text("Drag files here to park them").font(.headline).foregroundStyle(.white)
                    Text("Drag them out again into any app").font(.caption).foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.items, id: \.self) { url in
                            ShelfTile(url: url)
                        }
                    }
                    .padding(.vertical, 2)
                }
                HStack {
                    Text("\(store.items.count) \(store.items.count == 1 ? "file" : "files") · drag out to use")
                        .font(.caption2).foregroundStyle(.white.opacity(0.35))
                    Spacer()
                    Button("Clear") { store.clear() }
                        .buttonStyle(.plain).font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { store.prune() }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            FileDrop.load(providers) { store.add($0) }
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(targeted ? 0.9 : 0), lineWidth: 2)
        )
    }
}

private struct ShelfTile: View {
    let url: URL
    @ObservedObject private var store = ShelfStore.shared
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 40, height: 40)
            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
        .padding(.vertical, 8).padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(hovering ? 0.12 : 0.07)))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { store.remove(url) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(3)
                .help("Remove from shelf")
            }
        }
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: url as NSURL) }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Convert…") {
                ConvertModel.shared.select(url)
                NotchState.shared.selectedModule = "convert"
            }
            Divider()
            Button("Remove from shelf") { store.remove(url) }
        }
    }
}
