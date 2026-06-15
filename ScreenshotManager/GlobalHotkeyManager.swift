@preconcurrency import Carbon
import Foundation

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    nonisolated(unsafe) private static var action: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    @discardableResult
    func register(hotkey: AppHotkey, action: @escaping @MainActor () -> Void) -> Bool {
        unregister()
        Self.action = action

        let hotKeyID = EventHotKeyID(signature: "SSMN".fourCharCodeValue, id: 1)

        let hotKeyStatus = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard hotKeyStatus == noErr else {
            return false
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, _ -> OSStatus in
                guard let eventRef else {
                    return noErr
                }

                var receivedHotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &receivedHotKeyID
                )

                if receivedHotKeyID.signature == "SSMN".fourCharCodeValue, receivedHotKeyID.id == 1 {
                    Task { @MainActor in
                        GlobalHotkeyManager.action?()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard handlerStatus == noErr else {
            unregister()
            return false
        }

        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        unicodeScalars.prefix(4).reduce(0) { result, scalar in
            (result << 8) + FourCharCode(scalar.value)
        }
    }
}
