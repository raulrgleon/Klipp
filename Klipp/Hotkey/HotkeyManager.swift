import AppKit
import Carbon
import Foundation

final class HotkeyManager {
    static weak var shared: HotkeyManager?

    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: fourChar("KLIP"), id: 1)

    init() {
        HotkeyManager.shared = self
        installHandler()
    }

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func register(_ combo: KeyCombo) {
        unregister()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status != noErr {
            NSLog("Klipp: RegisterEventHotKey falló (%d)", status)
            return
        }
        hotKeyRef = ref
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            klippHotKeyHandler,
            1,
            &eventType,
            nil,
            &handlerRef
        )
        if status != noErr {
            NSLog("Klipp: InstallEventHandler falló (%d)", status)
        }
    }
}

private func klippHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        HotkeyManager.shared?.onPressed?()
    }
    return noErr
}

private func fourChar(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value)
    }
    return result
}
