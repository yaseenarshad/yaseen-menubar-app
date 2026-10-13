import AppKit
import Carbon.HIToolbox
import Testing
@testable import MenubarKit

/// The stored settings (YAZ-2801). Each test uses its own `UserDefaults` suite and removes it.
@Suite struct SettingsStoreTests {
    private func withStore(_ body: (SettingsStore, UserDefaults) -> Void) {
        let name = "MenubarKitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(SettingsStore(defaults: defaults), defaults)
    }

    @Test func theDefaults() {
        withStore { store, _ in
            #expect(store.hideAfterSeconds == 10)
            #expect(store.hotKey == nil)
            #expect(store.openAtLogin)
            #expect(!store.loginItemWasTried)
            #expect(!store.didFirstStart)
        }
    }

    // S30: the store never fails. A value that is not one of the four choices gives 10.
    @Test func hideAfterSecondsKeepsOnlyTheFourChoices() {
        withStore { store, defaults in
            for choice in [0, 5, 10, 30] {
                store.hideAfterSeconds = choice
                #expect(store.hideAfterSeconds == choice)
            }
            for broken: Any in [7, -1, 3600, "abc", 10.5] {
                defaults.set(broken, forKey: "hideAfterSeconds")
                #expect(store.hideAfterSeconds == 10, "stored value: \(broken)")
            }
        }
    }

    // S29, decision 11: there is no hotkey until the user records one.
    @Test func theHotKeyIsOptional() {
        withStore { store, defaults in
            let combo = HotKeyCombo(keyCode: UInt32(kVK_ANSI_B), modifiers: [.control, .option, .command])
            store.hotKey = combo
            #expect(store.hotKey == combo)

            store.hotKey = nil
            #expect(store.hotKey == nil)
            #expect(defaults.object(forKey: "hotKeyCode") == nil)
            #expect(defaults.object(forKey: "hotKeyModifiers") == nil)

            // Broken values give no hotkey. They do not give a default hotkey.
            defaults.set(9999, forKey: "hotKeyCode")
            defaults.set(-5, forKey: "hotKeyModifiers")
            #expect(store.hotKey == nil)
        }
    }

    @Test func aSecondStoreReadsTheSameValues() {
        withStore { store, defaults in
            store.hideAfterSeconds = 30
            store.openAtLogin = false
            store.loginItemWasTried = true
            store.didFirstStart = true

            let second = SettingsStore(defaults: defaults)
            #expect(second.hideAfterSeconds == 30)
            #expect(!second.openAtLogin)
            #expect(second.loginItemWasTried)
            #expect(second.didFirstStart)
        }
    }
}
