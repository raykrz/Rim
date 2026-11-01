import SwiftUI

struct FocusModule: NotchModule {
    let id = "focus"
    let title = "Focus"
    let systemImage = "timer"

    @MainActor func makeView() -> AnyView { AnyView(FocusView()) }
}

private struct FocusView: View {
    @ObservedObject private var focus = FocusModel.shared
    @ObservedObject private var media = NowPlayingModel.shared

    var body: some View {
        HStack(spacing: 14) {
            timerCard
            mediaCard
        }
        .onAppear { media.start() }
        .onDisappear { media.stop() }
    }

    // MARK: Timer

    private var timerCard: some View {
        VStack(spacing: 8) {
            Text(focus.completed ? "Done" : FocusModel.format(focus.remaining))
                .font(.system(size: 40, weight: .medium, design: .monospaced))
                .foregroundStyle(focus.completed ? Theme.success : .white)

            ProgressView(value: focus.progress)
                .progressViewStyle(.linear)
                .tint(focus.completed ? Theme.success : Theme.accent)

            if focus.isRunning || focus.isActive {
                TextField("What are you working on?", text: $focus.label)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                HStack(spacing: 6) {
                    ForEach([15, 25, 50], id: \.self) { minutes in
                        chip("\(minutes)m", selected: Int(focus.duration / 60) == minutes) { focus.setMinutes(minutes) }
                    }
                    chip("−5", selected: false) { focus.setMinutes(Int(focus.duration / 60) - 5) }
                    chip("+5", selected: false) { focus.setMinutes(Int(focus.duration / 60) + 5) }
                }
            }

            HStack(spacing: 8) {
                Button(focus.isRunning ? "Pause" : (focus.completed ? "Again" : (focus.isActive ? "Resume" : "Start"))) {
                    focus.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 16).padding(.vertical, 5)
                .background(Capsule().fill(Theme.accent))
                .foregroundStyle(.black)

                if focus.isActive {
                    Button("Reset") { focus.reset() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.14)))
                        .foregroundStyle(.white)
                }
            }

            Text("\(focus.sessionsToday) \(focus.sessionsToday == 1 ? "session" : "sessions") today")
                .font(.caption2).foregroundStyle(.white.opacity(0.35))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(selected ? Theme.accent.opacity(0.35) : .white.opacity(0.08)))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: Now playing

    private var mediaCard: some View {
        VStack(spacing: 8) {
            if let track = media.track {
                Image(systemName: track.app == "Spotify" ? "music.note" : "music.quarternote.3")
                    .font(.system(size: 22)).foregroundStyle(.white.opacity(0.5))
                VStack(spacing: 2) {
                    Text(track.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                    Text(track.artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    Text(track.app).font(.caption2).foregroundStyle(.white.opacity(0.35))
                }
                HStack(spacing: 18) {
                    control("backward.fill") { media.send("previous track") }
                    control(track.isPlaying ? "pause.fill" : "play.fill", size: 20) { media.send("playpause") }
                    control("forward.fill") { media.send("next track") }
                }
            } else if let app = media.permissionDenied {
                Image(systemName: "lock").font(.system(size: 22)).foregroundStyle(.white.opacity(0.5))
                Text("Allow RIM to control \(app) in System Settings > Privacy & Security > Automation.")
                    .font(.caption).foregroundStyle(Theme.accent).multilineTextAlignment(.center)
            } else {
                Image(systemName: "music.note").font(.system(size: 22)).foregroundStyle(.white.opacity(0.4))
                Text("Nothing playing").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                Text("Start Spotify or Music and the controls show up here.")
                    .font(.caption).foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))
    }

    private func control(_ symbol: String, size: CGFloat = 15, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size)).foregroundStyle(.white)
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
