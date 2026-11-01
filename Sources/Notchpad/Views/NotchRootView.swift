import SwiftUI

struct NotchRootView: View {
    @ObservedObject var state: NotchState

    private var size: CGSize { state.isOpen ? NotchGeometry.openSize : state.closedSize }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: state.isOpen ? 26 : 10)
                .fill(Color.black)
                .frame(width: size.width, height: size.height)

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
        HStack(spacing: 6) {
            ForEach(Array(ModuleRegistry.all.enumerated()), id: \.offset) { _, module in
                let selected = module.id == state.selectedModule
                Button {
                    state.selectedModule = module.id
                } label: {
                    Label(module.title, systemImage: module.systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(selected ? Color.white : .white.opacity(0.55))
                        .background(Capsule().fill(selected ? .white.opacity(0.16) : .clear))
                }
                .buttonStyle(.plain)
            }
        }
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
