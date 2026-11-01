import SwiftUI

/// Shown instead of the tabs while you're dragging files over the notch: pick where they should land.
struct DropChooser: View {
    @ObservedObject var state: NotchState

    var body: some View {
        HStack(spacing: 12) {
            zone(title: "Convert", subtitle: "Change the file type", systemImage: "arrow.triangle.2.circlepath", color: Theme.accent) { urls in
                if let first = urls.first { ConvertModel.shared.select(first) }
                state.selectedModule = "convert"
            }
            zone(title: "Shelf", subtitle: "Park it for later", systemImage: "tray.and.arrow.down", color: .white) { urls in
                ShelfStore.shared.add(urls)
                state.selectedModule = "shelf"
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func zone(title: String, subtitle: String, systemImage: String, color: Color, onDrop: @escaping ([URL]) -> Void) -> some View {
        DropZone(title: title, subtitle: subtitle, systemImage: systemImage, color: color) { urls in
            onDrop(urls)
            state.isDragging = false
        }
    }
}

private struct DropZone: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let onDrop: ([URL]) -> Void

    @State private var targeted = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 26))
            Text(title).font(.headline)
            Text(subtitle).font(.caption).opacity(0.7)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(targeted ? 0.5 : 0.22)))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(targeted ? 1 : 0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .animation(.easeOut(duration: 0.12), value: targeted)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            FileDrop.load(providers) { onDrop($0) }
            return true
        }
    }
}
