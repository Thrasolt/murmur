import Carbon
import Foundation

@MainActor
final class GlobalHotkey {
    var onPress: (@MainActor () -> Void)?
    var onRelease: (@MainActor () -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func register() throws {
        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let installStatus = eventTypes.withUnsafeBufferPointer { buffer in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let event, let userData else { return noErr }
                    let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                    switch GetEventKind(event) {
                    case UInt32(kEventHotKeyPressed):
                        MainActor.assumeIsolated { hotkey.onPress?() }
                    case UInt32(kEventHotKeyReleased):
                        MainActor.assumeIsolated { hotkey.onRelease?() }
                    default:
                        break
                    }
                    return noErr
                },
                buffer.count,
                buffer.baseAddress,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandler
            )
        }
        guard installStatus == noErr else { throw HotkeyError.registrationFailed }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D55524D), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { throw HotkeyError.registrationFailed }
    }

}

enum HotkeyError: LocalizedError {
    case registrationFailed
    var errorDescription: String? { "Option+Leertaste ist möglicherweise bereits belegt." }
}
