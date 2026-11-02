import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Needs no permissions, unlike watching key presses.
@MainActor
final class HotKey {
    private static var action: (() -> Void)?
    private var reference: EventHotKeyRef?

    /// Returns nil if another app already owns the shortcut.
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        Self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.action?() }
            return noErr
        }, 1, &eventType, nil, nil)

        let id = EventHotKeyID(signature: OSType(0x52494D21), id: 1)  // 'RIM!'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &reference)
        if status != noErr { return nil }
    }
}
