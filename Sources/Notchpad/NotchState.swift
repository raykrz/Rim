import Combine
import CoreGraphics

@MainActor
final class NotchState: ObservableObject {
    static let shared = NotchState()

    @Published var isOpen = false
    @Published var pinned = false
    /// True while files are being dragged over the open notch and no drop has happened yet.
    @Published var isDragging = false
    @Published var selectedModule = ModuleRegistry.all[0].id
    @Published var closedSize = CGSize(width: 190, height: 24)
    @Published var hasNotch = false
}
