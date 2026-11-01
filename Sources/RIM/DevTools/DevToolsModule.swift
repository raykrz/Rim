import AppKit
import SwiftUI

struct DevToolsModule: NotchModule {
    let id = "devtools"
    let title = "Dev tools"
    let systemImage = "hammer"

    @MainActor func makeView() -> AnyView { AnyView(DevToolsView()) }
}

@MainActor
final class DevToolsModel: ObservableObject {
    static let shared = DevToolsModel()

    @Published var input = "" {
        didSet { if input != oldValue { rerun() } }
    }
    @Published private(set) var output = ""
    @Published private(set) var error: String?
    @Published private(set) var activeTool: String?
    @Published private(set) var copied = false

    private var loadedChangeCount = -1

    /// Pulls in the clipboard text when it has changed since the last time, unless it looks like a secret.
    func loadClipboardIfNew() {
        let pb = NSPasteboard.general
        guard pb.changeCount != loadedChangeCount else { return }
        loadedChangeCount = pb.changeCount
        guard let text = pb.string(forType: .string), !text.isEmpty,
              !pb.types.map({ $0.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) }).orFalse,
              ClipboardStore.classify(text) != .secret else { return }
        input = String(text.prefix(20_000))
    }

    func run(_ tool: DevTool) {
        activeTool = tool.id
        rerun()
    }

    func copyOutput() {
        guard !output.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(output, forType: .string)
        loadedChangeCount = pb.changeCount
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.copied = false }
    }

    private func rerun() {
        guard let id = activeTool, let tool = DevTools.tool(id: id) else { return }
        do {
            output = try tool.run(input)
            error = nil
        } catch {
            output = ""
            self.error = error.localizedDescription
        }
    }
}

private extension Optional where Wrapped == Bool {
    var orFalse: Bool { self ?? false }
}

private struct DevToolsView: View {
    @ObservedObject private var model = DevToolsModel.shared
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                editor(text: $model.input, placeholder: "Paste or type here", editable: true)
                    .focused($focused)
                    .frame(maxHeight: .infinity)
                outputBox
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 270)

            VStack(alignment: .leading, spacing: 6) {
                FlowRow(spacing: 5) {
                    ForEach(DevTools.all) { tool in
                        Button { model.run(tool) } label: {
                            Text(tool.title)
                                .font(.system(size: 10.5, weight: .medium))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(model.activeTool == tool.id ? Theme.accent.opacity(0.35) : .white.opacity(0.08)))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { model.loadClipboardIfNew() }
        .onChange(of: focused) { isFocused in
            // The panel doesn't activate the app, but typing and ⌘V need it to be active.
            if isFocused { NSApp.activate(ignoringOtherApps: true) }
        }
    }

    private var outputBox: some View {
        ZStack(alignment: .topTrailing) {
            if let error = model.error {
                Text(error).font(.system(size: 11)).foregroundStyle(Theme.warning)
                    .padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
            } else {
                editor(text: .constant(model.output), placeholder: "Pick a tool", editable: false)
            }
            if !model.output.isEmpty {
                Button(model.copied ? "Copied" : "Copy") { model.copyOutput() }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .foregroundStyle(model.copied ? Theme.success : .white)
                    .padding(5)
            }
        }
    }

    private func editor(text: Binding<String>, placeholder: String, editable: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .disabled(!editable)
                .padding(4)
            if text.wrappedValue.isEmpty {
                Text(placeholder).font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 9).padding(.vertical, 12).allowsHitTesting(false)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.07)))
    }
}
