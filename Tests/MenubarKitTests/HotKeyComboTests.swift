import AppKit
import Carbon.HIToolbox
import Testing
@testable import MenubarKit

@Suite struct HotKeyComboTests {
    private func combo(_ key: Int, _ modifiers: NSEvent.ModifierFlags) -> HotKeyCombo {
        HotKeyCombo(keyCode: UInt32(key), modifiers: modifiers)
    }

    @Test func theTextFormForCombinationsOfTheFourModifiers() {
        // The order is always ⌃⌥⇧⌘, in each of the 16 combinations.
        let all: [(NSEvent.ModifierFlags, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        for bits in 0..<16 {
            var modifiers: NSEvent.ModifierFlags = []
            var expected = ""
            for (index, modifier) in all.enumerated() where bits & (1 << index) != 0 {
                modifiers.insert(modifier.0)
                expected += modifier.1
            }
            #expect(combo(kVK_ANSI_B, modifiers).text == expected + "B")
        }
        // Other modifier flags do not count.
        #expect(combo(kVK_ANSI_B, [.command, .capsLock, .function, .numericPad]) == combo(kVK_ANSI_B, .command))
    }

    @Test func aCombinationWithNoCommandControlOrOptionIsNotValid() {
        #expect(!combo(kVK_ANSI_B, []).isValid)
        #expect(!combo(kVK_ANSI_B, .shift).isValid)
        #expect(!combo(kVK_F5, []).isValid)
        for modifier in [NSEvent.ModifierFlags.command, .control, .option] {
            #expect(combo(kVK_ANSI_B, modifier).isValid)
            #expect(combo(kVK_ANSI_B, [modifier, .shift]).isValid)
            // Escape stops the recording. It is never a hotkey.
            #expect(!combo(kVK_Escape, modifier).isValid)
        }
    }

    @Test func fKeysLettersDigitsAndNamedKeys() {
        let cases: [(Int, NSEvent.ModifierFlags, String)] = [
            (kVK_ANSI_A, .command, "⌘A"),
            (kVK_ANSI_Z, [.control, .command], "⌃⌘Z"),
            (kVK_ANSI_4, [.shift, .command], "⇧⌘4"),
            (kVK_ANSI_0, .option, "⌥0"),
            (kVK_F1, .command, "⌘F1"),
            (kVK_F12, [.control, .option], "⌃⌥F12"),
            (kVK_F20, .command, "⌘F20"),
            (kVK_Space, [.control, .option], "⌃⌥Space"),
            (kVK_Return, .command, "⌘↩"),
            (kVK_Tab, .option, "⌥⇥"),
            (kVK_Delete, .command, "⌘⌫"),
            (kVK_LeftArrow, .command, "⌘←"),
            (kVK_UpArrow, [.shift, .option], "⌥⇧↑"),
            (kVK_ANSI_Comma, .command, "⌘,"),
            // A key with no name still has a text form.
            (kVK_ANSI_Keypad5, .command, "⌘Key 87"),
        ]
        for (key, modifiers, text) in cases {
            #expect(combo(key, modifiers).text == text)
        }
    }

    @Test func theCombinationOfAKeyDownEvent() throws {
        func event(_ type: NSEvent.EventType, key: Int, _ modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
            try #require(NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0,
                context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(key)
            ))
        }
        // An arrow key always has the flags `.function` and `.numericPad`. They do not count.
        let arrow = try event(.keyDown, key: kVK_RightArrow, [.command, .option, .function, .numericPad])
        #expect(HotKeyCombo(keyDown: arrow) == combo(kVK_RightArrow, [.command, .option]))
        #expect(HotKeyCombo(keyDown: arrow)?.text == "⌥⌘→")

        let plain = try event(.keyDown, key: kVK_ANSI_B, [])
        #expect(HotKeyCombo(keyDown: plain)?.isValid == false)
        #expect(HotKeyCombo(keyDown: try event(.keyUp, key: kVK_ANSI_B, .command)) == nil)
    }
}
