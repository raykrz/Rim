import Combine
import CoreGraphics

@MainActor
final class NotchState: ObservableObject {
    @Published var isOpen = false
    @Published var pinned = false
    @Published var selectedModule = ModuleRegistry.all[0].id
    @Published var closedSize = CGSize(width: 190, height: 24)
    @Published var hasNotch = false
}
