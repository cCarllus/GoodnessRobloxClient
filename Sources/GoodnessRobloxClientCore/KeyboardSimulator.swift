import AppKit
import ApplicationServices
import Foundation

public struct KeyStroke: Equatable {
    public let keyCode: CGKeyCode
    public let flags: CGEventFlags
}

public enum KeyboardSimulatorError: LocalizedError {
    case unsupportedCharacter(Character)
    case eventCreationFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedCharacter(let character):
            return "Caractere nao suportado pelo mapa de teclado: \(character)"
        case .eventCreationFailed:
            return "Nao foi possivel criar o evento de teclado."
        }
    }
}

public final class KeyboardSimulator {
    public static let shared = KeyboardSimulator()

    private init() { }

    public var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    public func pressChord(_ keys: [Character], holdDuration: TimeInterval) async throws {
        let strokes = try keys.map(resolveKeyStroke)

        for stroke in strokes {
            try post(stroke: stroke, keyDown: true)
        }

        try await Task.sleep(nanoseconds: UInt64(max(0.01, holdDuration) * 1_000_000_000))

        for stroke in strokes.reversed() {
            try post(stroke: stroke, keyDown: false)
        }
    }

    private func post(stroke: KeyStroke, keyDown: Bool) throws {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: stroke.keyCode, keyDown: keyDown) else {
            throw KeyboardSimulatorError.eventCreationFailed
        }
        event.flags = stroke.flags
        event.post(tap: .cghidEventTap)
    }

    private func resolveKeyStroke(for character: Character) throws -> KeyStroke {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            throw KeyboardSimulatorError.unsupportedCharacter(character)
        }

        let value = scalar.value
        if value >= 65 && value <= 90 {
            let lower = Character(UnicodeScalar(value + 32)!)
            guard let keyCode = Self.baseKeyCodes[lower] else {
                throw KeyboardSimulatorError.unsupportedCharacter(character)
            }
            return KeyStroke(keyCode: keyCode, flags: .maskShift)
        }

        if let keyCode = Self.baseKeyCodes[character] {
            return KeyStroke(keyCode: keyCode, flags: [])
        }

        if let shifted = Self.shiftedKeyCodes[character] {
            return KeyStroke(keyCode: shifted, flags: .maskShift)
        }

        throw KeyboardSimulatorError.unsupportedCharacter(character)
    }

    private static let baseKeyCodes: [Character: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
        "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50, " ": 49
    ]

    private static let shiftedKeyCodes: [Character: CGKeyCode] = [
        "!": 18, "@": 19, "#": 20, "$": 21, "^": 22, "%": 23, "+": 24,
        "(": 25, "&": 26, "_": 27, "*": 28, ")": 29, "}": 30, "{": 33,
        "\"": 39, ":": 41, "|": 42, "<": 43, "?": 44, ">": 47, "~": 50
    ]
}
