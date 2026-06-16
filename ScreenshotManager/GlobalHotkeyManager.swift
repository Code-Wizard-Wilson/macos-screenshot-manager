@preconcurrency import Carbon
import Foundation

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    nonisolated(unsafe) private static var actions: [UInt32: @MainActor () -> Void] = [:]

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    private init() {}

    @discardableResult
    func register(id: UInt32, hotkey: AppHotkey, action: @escaping @MainActor () -> Void) -> Bool {
        unregister(id: id)
        Self.actions[id] = action

        let hotKeyID = EventHotKeyID(signature: "SSMN".fourCharCodeValue, id: id)
        var hotKeyRef: EventHotKeyRef?

        let hotKeyStatus = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard hotKeyStatus == noErr else {
            Self.actions[id] = nil
            return false
        }

        hotKeyRefs[id] = hotKeyRef

        guard installEventHandlerIfNeeded() else {
            unregister(id: id)
            return false
        }

        return true
    }

    func unregister(id: UInt32) {
        if let hotKeyRef = hotKeyRefs[id] {
            UnregisterEventHotKey(hotKeyRef)
            hotKeyRefs[id] = nil
        }

        Self.actions[id] = nil
    }

    func unregisterAll() {
        hotKeyRefs.values.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        Self.actions.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandler == nil else {
            return true
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

                if receivedHotKeyID.signature == "SSMN".fourCharCodeValue {
                    let actionID = receivedHotKeyID.id
                    Task { @MainActor in
                        GlobalHotkeyManager.actions[actionID]?()
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
            return false
        }

        return true
    }

    func unregister() {
        unregisterAll()
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        unicodeScalars.prefix(4).reduce(0) { result, scalar in
            (result << 8) + FourCharCode(scalar.value)
        }
    }
}
