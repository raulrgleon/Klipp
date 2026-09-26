import AppKit
import Carbon

struct KeyCombo: Equatable, Hashable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers.rawValue)
    }

    static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers.intersection([.command, .shift, .option, .control]) == rhs.modifiers.intersection([.command, .shift, .option, .control])
    }

    static let `default` = KeyCombo(keyCode: 9, modifiers: [.command, .shift]) // ⌘⇧V

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    var storedModifiers: Int {
        var raw = 0
        if modifiers.contains(.command) { raw |= 1 << 0 }
        if modifiers.contains(.shift) { raw |= 1 << 1 }
        if modifiers.contains(.option) { raw |= 1 << 2 }
        if modifiers.contains(.control) { raw |= 1 << 3 }
        return raw
    }

    static func fromStored(keyCode: Int, modifiers: Int) -> KeyCombo {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & (1 << 0) != 0 { flags.insert(.command) }
        if modifiers & (1 << 1) != 0 { flags.insert(.shift) }
        if modifiers & (1 << 2) != 0 { flags.insert(.option) }
        if modifiers & (1 << 3) != 0 { flags.insert(.control) }
        return KeyCombo(keyCode: UInt16(keyCode), modifiers: flags)
    }

    static func from(event: NSEvent) -> KeyCombo? {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !flags.isEmpty else { return nil }
        let ignored: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        guard !ignored.contains(event.keyCode) else { return nil }
        return KeyCombo(keyCode: event.keyCode, modifiers: flags)
    }

    static func keyName(for keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "⏎",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 49: "Espacio", 50: "`",
            51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12",
            118: "F4", 120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return map[keyCode] ?? "Key\(keyCode)"
    }
}
