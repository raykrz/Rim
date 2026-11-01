import SwiftUI

struct NotchRootView: View {
    @ObservedObject var state: NotchState

    @ObservedObject private var focus = FocusModel.shared

    private var showWings: Bool { !state.isOpen && focus.isActive }
    private var size: CGSize { state.isOpen ? NotchGeometry.openSize : state.collapsedSize }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: state.isOpen ? 26 : 10)
                .fill(Color.black)
                .frame(width: size.width, height: size.height)

            // A thin edge of light along the bottom, fading toward the top.
            NotchShape(bottomRadius: state.isOpen ? 26 : 10)
                .stroke(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.07), Theme.accent.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .frame(width: size.width - 1, height: size.height - 1)
                .opacity(state.isOpen ? 1 : 0)

            if showWings {
                wings
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
            }

            if state.isOpen {
                content
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .transition(.opacity.animation(.easeOut(duration: 0.15).delay(0.12)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: state.isOpen)
        .preferredColorScheme(.dark)
    }

    /// Timer progress on the left of the notch and the time left on the right.
    private var wings: some View {
        HStack(spacing: 0) {
            ZStack {
                if focus.completed {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.success)
                } else {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 2)
                    Circle().trim(from: 0, to: focus.progress)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 14, height: 14)
            .frame(width: NotchGeometry.wing)

            Spacer(minLength: 0)

            Text(focus.completed ? "Done" : FocusModel.format(focus.remaining))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(focus.completed ? Theme.success : .white.opacity(focus.isRunning ? 0.95 : 0.5))
                .frame(width: NotchGeometry.wing)
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            if state.isDragging {
                DropChooser(state: state)
            } else {
                tabBar
                if let module = ModuleRegistry.module(id: state.selectedModule) {
                    module.makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.top, state.closedSize.height + 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(ModuleRegistry.all.enumerated()), id: \.offset) { _, module in
                let selected = module.id == state.selectedModule
                Button {
                    state.selectedModule = module.id
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: module.systemImage)
                            .font(.system(size: 11, weight: .medium))
                        if selected {
                            Text(module.title.lowercased())
                                .font(.system(size: 11, weight: .medium))
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, selected ? 10 : 8).padding(.vertical, 5)
                    .foregroundStyle(selected ? Color.white : .white.opacity(0.45))
                    .background(Capsule().fill(selected ? .white.opacity(0.14) : .clear))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(module.title)
            }

            Spacer()

            Menu {
                Button(state.pinned ? "Unpin" : "Keep open") { state.pinned.toggle() }
                Divider()
                Button("Quit RIM") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: state.pinned ? "pin.fill" : "ellipsis")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .animation(.easeOut(duration: 0.15), value: state.selectedModule)
    }
}

/// Flat top, rounded bottom corners, like the hardware notch.
struct NotchShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
