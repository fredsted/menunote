//
//  HotKey.swift
//  MenuNote
//

import AppKit
import Carbon.HIToolbox

/// A key combination, stored as a virtual key code plus modifier flags.
struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlags: UInt
    var keyName: String

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, keyName: String) {
        self.keyCode = keyCode
        self.modifierFlags = modifiers.rawValue
        self.keyName = keyName
    }

    init(event: NSEvent) {
        self.init(
            keyCode: UInt32(event.keyCode),
            modifiers: event.modifierFlags.intersection(Self.relevantModifiers),
            keyName: Self.keyName(for: event)
        )
    }

    static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierFlags) }

    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + keyName
    }

    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        if modifiers.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }

    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func keyName(for event: NSEvent) -> String {
        if let name = specialKeyNames[Int(event.keyCode)] { return name }
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }
}

/// Registers a single system-wide hotkey via Carbon (works without Accessibility permission).
final class GlobalHotKey {
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private static var instance: GlobalHotKey?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { GlobalHotKey.instance?.onPress?() }
            return noErr
        }, 1, &eventType, nil, nil)
        Self.instance = self
    }

    func register(_ hotKey: HotKey?) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        guard let hotKey else { return }
        let id = EventHotKeyID(signature: OSType(0x4D4E_4F54), id: 1) // 'MNOT'
        RegisterEventHotKey(hotKey.keyCode, hotKey.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
