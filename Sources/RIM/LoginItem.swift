import ServiceManagement

/// Starts RIM when you log in. Works from the installed app, not from `swift run`.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func toggle() {
        do {
            if isEnabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch {
            DebugLog.write("launch at login failed: \(error.localizedDescription)")
        }
    }
}
