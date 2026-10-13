import AppKit
import Carbon.HIToolbox
import Testing
@testable import MenubarKit

/// The rules of the settings window (YAZ-2801), with no window, no real hotkey and no real login item.
@MainActor
@Suite struct SettingsModelTests {
    private let controlOptionB = HotKeyCombo(keyCode: UInt32(kVK_ANSI_B), modifiers: [.control, .option])
    private let commandF6 = HotKeyCombo(keyCode: UInt32(kVK_F6), modifiers: .command)
    private let escape = HotKeyCombo(keyCode: UInt32(kVK_Escape), modifiers: [])

    private func makeModel(
        _ defaults: UserDefaults = MemoryDefaults(),
        hotKeys: FakeHotKeys = FakeHotKeys(),
        loginItem: FakeLoginItem = FakeLoginItem()
    ) -> SettingsModel {
        SettingsModel(store: SettingsStore(defaults: defaults), hotKeys: hotKeys, loginItem: loginItem)
    }

    // MARK: Hide again after

    // S30, decision 7.
    @Test func aNewDelayIsSavedAndToldToTheApp() {
        let defaults = MemoryDefaults()
        let model = makeModel(defaults)
        var told: [Int] = []
        model.onHideAfterChanged = { told.append($0) }

        #expect(model.hideAfterSeconds == 10)
        #expect(SettingsModel.hideAfterChoices == [5, 10, 30, 0])
        #expect(SettingsModel.hideAfterChoices.map(SettingsModel.hideAfterText) == ["5 seconds", "10 seconds", "30 seconds", "Never"])

        model.setHideAfterSeconds(30)
        model.setHideAfterSeconds(0)
        #expect(model.hideAfterSeconds == 0)
        #expect(told == [30, 0])
        #expect(SettingsStore(defaults: defaults).hideAfterSeconds == 0)

        // A value that is not one of the four choices changes nothing.
        model.setHideAfterSeconds(7)
        #expect(model.hideAfterSeconds == 0)
        #expect(told == [30, 0])
        #expect(SettingsStore(defaults: defaults).hideAfterSeconds == 0)

        // A broken stored value shows as 10.
        defaults.set(7, forKey: "hideAfterSeconds")
        #expect(makeModel(defaults).hideAfterSeconds == 10)
    }

    // MARK: The hotkey (S29, decision 11)

    @Test func thereIsNoHotKeyUntilTheUserRecordsOne() {
        let defaults = MemoryDefaults()
        let hotKeys = FakeHotKeys()
        let model = makeModel(defaults, hotKeys: hotKeys)

        model.registerHotKey()
        #expect(model.hotKey == nil)
        #expect(hotKeys.registered == nil)
        #expect(model.hotKeyProblem == nil)
        #expect(model.hotKeyText == "Record shortcut")
        // A key in the window while the field does not record is not for the model.
        #expect(model.keyDown(controlOptionB) == false)

        model.startRecording()
        #expect(model.isRecording)
        #expect(model.hotKeyText == "Type a shortcut")

        // Only Shift, or no modifier: not accepted, and the field continues to record.
        #expect(model.keyDown(HotKeyCombo(keyCode: UInt32(kVK_ANSI_B), modifiers: .shift)) == true)
        #expect(model.keyDown(HotKeyCombo(keyCode: UInt32(kVK_ANSI_B), modifiers: [])) == true)
        #expect(model.isRecording)
        #expect(hotKeys.registered == nil)

        #expect(model.keyDown(controlOptionB) == true)
        #expect(!model.isRecording)
        #expect(hotKeys.registered == controlOptionB)
        #expect(model.hotKey == controlOptionB)
        #expect(model.hotKeyText == "⌃⌥B")
        #expect(model.hotKeyProblem == nil)
        // A new store on the same defaults: the hotkey is saved.
        #expect(SettingsStore(defaults: defaults).hotKey == controlOptionB)

        // The next start registers the saved hotkey.
        let nextHotKeys = FakeHotKeys()
        makeModel(defaults, hotKeys: nextHotKeys).registerHotKey()
        #expect(nextHotKeys.registered == controlOptionB)
    }

    @Test func aRecordingThatStopsKeepsTheEarlierHotKey() {
        let defaults = MemoryDefaults()
        let hotKeys = FakeHotKeys()
        let model = makeModel(defaults, hotKeys: hotKeys)

        // With no earlier hotkey, Esc leaves none.
        model.startRecording()
        #expect(model.keyDown(escape) == true)
        #expect(!model.isRecording)
        #expect(model.hotKey == nil)
        #expect(hotKeys.registered == nil)

        model.startRecording()
        _ = model.keyDown(controlOptionB)

        // While the field records, the app does not listen for the earlier hotkey.
        model.startRecording()
        #expect(hotKeys.registered == nil)
        // Esc stops the recording. The earlier hotkey stays, and it listens again.
        #expect(model.keyDown(escape) == true)
        #expect(!model.isRecording)
        #expect(hotKeys.registered == controlOptionB)
        #expect(model.hotKey == controlOptionB)

        // The window closes during a recording: the same as Esc.
        model.startRecording()
        model.cancelRecording()
        #expect(hotKeys.registered == controlOptionB)
        #expect(SettingsStore(defaults: defaults).hotKey == controlOptionB)
    }

    @Test func aHotKeyThatMacOSRefusesKeepsTheEarlierOne() {
        let defaults = MemoryDefaults()
        let hotKeys = FakeHotKeys()
        hotKeys.refused = [commandF6]
        let model = makeModel(defaults, hotKeys: hotKeys)

        // No earlier hotkey: the window tells the problem, and there is still no hotkey.
        model.startRecording()
        #expect(model.keyDown(commandF6) == true)
        #expect(!model.isRecording)
        #expect(model.hotKeyProblem == "That shortcut is in use.")
        #expect(model.hotKey == nil)
        #expect(hotKeys.registered == nil)
        #expect(SettingsStore(defaults: defaults).hotKey == nil)

        // The line goes away when the next recording starts.
        model.startRecording()
        #expect(model.hotKeyProblem == nil)
        _ = model.keyDown(controlOptionB)
        #expect(model.hotKey == controlOptionB)

        // With an earlier hotkey: it stays, and it listens again.
        model.startRecording()
        #expect(model.keyDown(commandF6) == true)
        #expect(model.hotKeyProblem == "That shortcut is in use.")
        #expect(model.hotKey == controlOptionB)
        #expect(hotKeys.registered == controlOptionB)
        #expect(SettingsStore(defaults: defaults).hotKey == controlOptionB)

        // The stored hotkey cannot be registered at the start: the model tells it and nothing more.
        hotKeys.refused = [controlOptionB]
        let atStart = makeModel(defaults, hotKeys: hotKeys)
        atStart.registerHotKey()
        #expect(atStart.hotKeyProblem == "That shortcut is in use.")
        #expect(atStart.hotKey == controlOptionB)
    }

    @Test func clearRemovesTheHotKey() {
        let defaults = MemoryDefaults()
        let hotKeys = FakeHotKeys()
        let model = makeModel(defaults, hotKeys: hotKeys)
        model.startRecording()
        _ = model.keyDown(controlOptionB)

        model.clearHotKey()
        #expect(model.hotKey == nil)
        #expect(hotKeys.registered == nil)
        #expect(model.hotKeyText == "Record shortcut")
        #expect(SettingsStore(defaults: defaults).hotKey == nil)
        #expect(defaults.object(forKey: "hotKeyCode") == nil)
        #expect(defaults.object(forKey: "hotKeyModifiers") == nil)

        // "Clear" during a recording stops the recording too. The earlier hotkey does not come back.
        model.startRecording()
        _ = model.keyDown(controlOptionB)
        model.startRecording()
        model.clearHotKey()
        #expect(!model.isRecording)
        #expect(model.hotKey == nil)
        #expect(hotKeys.registered == nil)

        // "Clear" removes the line of a refused hotkey.
        hotKeys.refused = [commandF6]
        model.startRecording()
        _ = model.keyDown(commandF6)
        #expect(model.hotKeyProblem != nil)
        model.clearHotKey()
        #expect(model.hotKeyProblem == nil)
    }

    // MARK: Open at login

    // S27.
    @Test func theFirstStartRegistersTheLoginItemOneTime() {
        let defaults = MemoryDefaults()
        let loginItem = FakeLoginItem()
        let model = makeModel(defaults, loginItem: loginItem)
        #expect(model.openAtLogin == false)

        model.registerLoginItemAtFirstStart()
        #expect(loginItem.calls == [true])
        #expect(model.openAtLogin == true)

        // The user turns it off in System Settings. A later start does not register again.
        loginItem.isEnabled = false
        let later = makeModel(defaults, loginItem: loginItem)
        later.registerLoginItemAtFirstStart()
        #expect(loginItem.calls == [true])
        #expect(later.openAtLogin == false)

        // The first registration fails: the app tells nothing, the switch shows off, and there is no second try.
        let refusing = FakeLoginItem()
        refusing.refuses = true
        let failed = makeModel(loginItem: refusing)
        failed.registerLoginItemAtFirstStart()
        failed.registerLoginItemAtFirstStart()
        #expect(refusing.calls == [true])
        #expect(failed.openAtLogin == false)
        #expect(failed.loginItemProblem == nil)
    }

    // S27: the switch shows the real state from macOS.
    @Test func theSwitchShowsTheRealStateAndGoesBackWhenMacOSRefuses() {
        let defaults = MemoryDefaults()
        let store = SettingsStore(defaults: defaults)
        let loginItem = FakeLoginItem()
        let model = makeModel(defaults, loginItem: loginItem)

        // The stored value tells on (the default), but macOS tells off. The switch shows off.
        #expect(store.openAtLogin == true)
        #expect(model.openAtLogin == false)
        // A change in System Settings shows after a refresh.
        loginItem.isEnabled = true
        model.refreshOpenAtLogin()
        #expect(model.openAtLogin == true)

        model.setOpenAtLogin(false)
        #expect(loginItem.calls == [false])
        #expect(model.openAtLogin == false)
        #expect(store.openAtLogin == false)
        #expect(model.loginItemProblem == nil)

        // macOS refuses: the switch goes back, and the red line shows the reason.
        loginItem.refuses = true
        model.setOpenAtLogin(true)
        #expect(model.openAtLogin == false)
        #expect(model.loginItemProblem == "Operation not permitted")
        #expect(store.openAtLogin == false)

        // No error, but no change: the switch goes back with a line too.
        loginItem.refuses = false
        loginItem.ignores = true
        model.setOpenAtLogin(true)
        #expect(model.openAtLogin == false)
        #expect(model.loginItemProblem == SettingsModel.loginItemNotChangedText)

        // A change that works removes the red line.
        loginItem.ignores = false
        model.setOpenAtLogin(true)
        #expect(model.openAtLogin == true)
        #expect(model.loginItemProblem == nil)
        #expect(store.openAtLogin == true)
    }

    // S28.
    @Test func outsideTheAppBundleTheSwitchIsDisabledAndNothingIsRegistered() {
        let defaults = MemoryDefaults()
        let loginItem = FakeLoginItem()
        loginItem.isAvailable = false
        loginItem.isEnabled = true
        let model = makeModel(defaults, loginItem: loginItem)

        model.registerLoginItemAtFirstStart()
        model.setOpenAtLogin(true)
        #expect(loginItem.calls.isEmpty)
        #expect(model.openAtLogin == false)
        #expect(model.loginItemIsAvailable == false)
        #expect(model.loginItemNote == "Open at login works only in the installed app.")
        // The one try is still free for the installed app.
        #expect(SettingsStore(defaults: defaults).loginItemWasTried == false)
    }
}
