import SwiftUI
import UniformTypeIdentifiers

struct ConvertModule: NotchModule {
    let id = "convert"
    let title = "Convert"
    let systemImage = "arrow.triangle.2.circlepath"

    @MainActor func makeView() -> AnyView { AnyView(ConvertView()) }
}

@MainActor
final class ConvertModel: ObservableObject {
    static let shared = ConvertModel()

    enum Status: Equatable {
        case idle
        case working(String)
        case done(URL)
        case failed(String)
    }

    @Published private(set) var file: URL?
    @Published private(set) var actions: [ConvertAction] = []
    @Published private(set) var status: Status = .idle
    @Published private(set) var message: String?

    func select(_ url: URL) {
        file = url
        actions = Converter.actions(for: url)
        status = .idle
        message = actions.isEmpty ? "Notchpad can't convert .\(url.pathExtension.lowercased()) files yet." : nil
    }

    func useFinderSelection() {
        switch FinderSelection.urls() {
        case .failure(let error):
            message = error.message
        case .success(let urls):
            // Pick the first selected file we know how to convert.
            if let match = urls.first(where: { !Converter.actions(for: $0).isEmpty }) ?? urls.first {
                select(match)
            } else {
                message = "Select a file in Finder first."
            }
        }
    }

    func run(_ action: ConvertAction) {
        guard let source = file else { return }
        let destination = Converter.destination(for: source, ext: action.outputExtension)
        status = .working(action.title)
        Task {
            do {
                try await action.perform(source, destination)
                status = .done(destination)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                status = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        file = nil
        actions = []
        status = .idle
        message = nil
    }
}

private struct ConvertView: View {
    @ObservedObject private var model = ConvertModel.shared
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 10) {
            if let file = model.file {
                fileHeader(file)
                actionArea
            } else {
                dropZone
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in model.select(url) }
            }
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(targeted ? 0.9 : 0), lineWidth: 2)
        )
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc").font(.system(size: 26)).foregroundStyle(.white.opacity(0.5))
            Text("Drop a file here").font(.headline).foregroundStyle(.white)
            Text("PDF, Word, images, video and text files").font(.caption).foregroundStyle(.white.opacity(0.55))
            Button("Use Finder selection") { model.useFinderSelection() }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.14)))
                .foregroundStyle(.white)
            if let message = model.message {
                Text(message).font(.caption2).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
        }
    }

    private func fileHeader(_ file: URL) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path)).resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.lastPathComponent).font(.system(size: 12, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                Text(fileSize(file)).font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button { model.reset() } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Choose another file")
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.07)))
    }

    @ViewBuilder
    private var actionArea: some View {
        if let message = model.message {
            Text(message).font(.caption).foregroundStyle(.orange)
        }
        FlowRow(spacing: 6) {
            ForEach(model.actions) { action in
                Button { model.run(action) } label: {
                    Text(action.title)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.purple.opacity(0.35)))
                        .overlay(Capsule().strokeBorder(Color.purple.opacity(0.7), lineWidth: 0.5))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        statusView
        Spacer(minLength: 0)
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .idle:
            EmptyView()
        case .working(let title):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Converting \(title)…").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
        case .done(let url):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Saved \(url.lastPathComponent)").font(.caption).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    .buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(.blue)
            }
        case .failed(let reason):
            Text(reason).font(.caption).foregroundStyle(.red).lineLimit(2)
        }
    }

    private func fileSize(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

/// Minimal wrapping row layout for chips.
private struct FlowRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 400, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (origins, CGSize(width: maxX, height: y + rowHeight))
    }
}
