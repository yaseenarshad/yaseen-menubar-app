import AppKit
import Carbon.HIToolbox

/// The state and the rules of the settings window, with no window and no view.
///
/// The model owns the changes of the three settings: it stores the values, registers the hotkey,
/// and asks macOS for "open at login". The app and the window only call it. Thus a test proves the rules.
@MainActor
final class SettingsModel: ObservableObject {
    static let hotKeyInUseText = "That hotkey is in use."
    static let loginItemNotAvailableText = "Open at login works only in the installed app."
    static let loginItemNotChangedText = "macOS did not change this setting. Look at Login Items in System Settings."

    static let hideAfterChoices = SettingsStore.hideAfterChoices

    /// The delay before the icons hide again. 0 is "Never".
    @Published private(set) var hideAfterSeconds: Int
    /// `nil` until the user records a hotkey.
    @Published private(set) var hotKey: HotKeyCombo?
    /// True while the hotkey field waits for a combination. The global hotkey is off during that time.
    @Published private(set) var isRecording = false
    /// The red line below the hotkey field.
    @Published private(set) var hotKeyProblem: String?
    /// The real state from macOS, not the stored value.
    @Published private(set) var openAtLogin = false
    /// The red line below the switch.
    @Published private(set) var loginItemProblem: String?

    /// The app gives the new delay to the timer.
    var onHideAfterChanged: (Int) -> Void = { _ in }

    private let store: SettingsStore
    private let hotKeys: HotKeyRegistering
    private let loginItem: LoginItem

    init(store: SettingsStore, hotKeys: HotKeyRegistering, loginItem: LoginItem) {
        self.store = store
        self.hotKeys = hotKeys
        self.loginItem = loginItem
        hideAfterSeconds = store.hideAfterSeconds
        hotKey = store.hotKey
        refreshOpenAtLogin()
    }

    // MARK: Hide again after

    /// The name of a choice in the settings window.
    static func hideAfterText(_ seconds: Int) -> String {
        seconds == 0 ? "Never" : "\(seconds) seconds"
    }

    func setHideAfterSeconds(_ seconds: Int) {
        guard SettingsModel.hideAfterChoices.contains(seconds) else { return }
        hideAfterSeconds = seconds
        store.hideAfterSeconds = seconds
        onHideAfterChanged(seconds)
    }

    // MARK: The hotkey

    /// The text on the hotkey field.
    var hotKeyText: String {
        if isRecording { return "Type a hotkey" }
        return hotKey?.text ?? "Record hotkey"
    }

    /// Registers the stored hotkey, if there is one. The app calls this at the start.
    /// When macOS refuses, the app continues to run and the window shows the red line.
    func registerHotKey() {
        guard let hotKey = hotKey else { return }
        hotKeyProblem = hotKeys.register(hotKey) ? nil : SettingsModel.hotKeyInUseText
    }

    func startRecording() {
        guard !isRecording else { return }
        // With the earlier hotkey still registered, macOS would give the keys to the app and not to the field.
        hotKeys.unregister()
        hotKeyProblem = nil
        isRecording = true
    }

    /// Stops the recording and keeps the earlier hotkey.
    func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        registerHotKey()
    }

    /// A key-down in the settings window. Returns `true` when the model used the key.
    func keyDown(_ combo: HotKeyCombo) -> Bool {
        guard isRecording else { return false }
        if combo.keyCode == UInt32(kVK_Escape) {
            cancelRecording()
            return true
        }
        // Not valid (only Shift, or no modifier): the field continues to record.
        guard combo.isValid else { return true }

        isRecording = false
        if hotKeys.register(combo) {
            // Save only a combination that macOS accepted.
            hotKey = combo
            store.hotKey = combo
        } else {
            // The failed call left no hotkey registered. Put the earlier one back.
            registerHotKey()
            hotKeyProblem = SettingsModel.hotKeyInUseText
        }
        return true
    }

    /// "Clear": the app has no hotkey again.
    func clearHotKey() {
        isRecording = false
        hotKeys.unregister()
        hotKey = nil
        store.hotKey = nil
        hotKeyProblem = nil
    }

    // MARK: Open at login

    var loginItemIsAvailable: Bool { loginItem.isAvailable }

    /// The grey line below the switch.
    var loginItemNote: String? {
        loginItem.isAvailable ? nil : SettingsModel.loginItemNotAvailableText
    }

    /// Reads the real state again. The user can change it in System Settings while the app runs.
    func refreshOpenAtLogin() {
        openAtLogin = loginItem.isAvailable && loginItem.isEnabled
    }

    /// The first start registers the app one time (the default is on). A failure tells nothing.
    /// Safe to call at each start: after the first call it does nothing.
    func registerLoginItemAtFirstStart() {
        // Outside the bundle there is nothing to register. Do not use up the one try there.
        guard loginItem.isAvailable, !store.loginItemWasTried else { return }
        store.loginItemWasTried = true
        if !loginItem.isEnabled {
            try? loginItem.setEnabled(true)
        }
        refreshOpenAtLogin()
    }

    /// The switch. When macOS refuses the change, the switch goes back and the red line shows the reason.
    func setOpenAtLogin(_ enabled: Bool) {
        guard loginItem.isAvailable else { return }
        do {
            try loginItem.setEnabled(enabled)
            loginItemProblem = nil
        } catch {
            loginItemProblem = error.localizedDescription
        }
        refreshOpenAtLogin()
        if openAtLogin != enabled, loginItemProblem == nil {
            // macOS gave no error but the state is not the new one (for example, the user must approve the app).
            loginItemProblem = SettingsModel.loginItemNotChangedText
        }
    }
}
