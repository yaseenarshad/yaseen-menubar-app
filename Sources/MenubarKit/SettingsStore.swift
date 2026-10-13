import AppKit

/// All the stored values of the app, in `UserDefaults`. The list never grows.
///
/// The `UserDefaults` is a parameter, so a test gives one that keeps its values in memory.
/// A value that is missing or broken gives the default. The store never fails.
public final class SettingsStore {
    private enum Key {
        static let hideAfterSeconds = "hideAfterSeconds"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let loginItemWasTried = "loginItemWasTried"
        static let didFirstStart = "didFirstStart"
    }

    /// The choices for `hideAfterSeconds`, in the order of the settings window. 0 is "Never".
    public static let hideAfterChoices = [5, 10, 30, 0]
    public static let defaultHideAfterSeconds = 10

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The delay before the icons hide again. 0 is "Never".
    public var hideAfterSeconds: Int {
        get {
            guard
                let seconds = defaults.object(forKey: Key.hideAfterSeconds) as? Int,
                SettingsStore.hideAfterChoices.contains(seconds)
            else { return SettingsStore.defaultHideAfterSeconds }
            return seconds
        }
        set { defaults.set(newValue, forKey: Key.hideAfterSeconds) }
    }

    /// The global hotkey. There is none until the user records one.
    public var hotKey: HotKeyCombo? {
        get {
            guard
                let code = defaults.object(forKey: Key.hotKeyCode) as? Int,
                let modifiers = defaults.object(forKey: Key.hotKeyModifiers) as? Int,
                // A virtual key code is one byte.
                (0...0xFF).contains(code), modifiers >= 0
            else { return nil }
            let combo = HotKeyCombo(
                keyCode: UInt32(code),
                modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers))
            )
            return combo.isValid ? combo : nil
        }
        set {
            guard let combo = newValue else {
                defaults.removeObject(forKey: Key.hotKeyCode)
                defaults.removeObject(forKey: Key.hotKeyModifiers)
                return
            }
            defaults.set(Int(combo.keyCode), forKey: Key.hotKeyCode)
            defaults.set(Int(combo.modifiers.rawValue), forKey: Key.hotKeyModifiers)
        }
    }

    /// True after the first start tried to register the app as a login item. The app tries one time only.
    /// The app does not store "open at login" itself: the state is in macOS (`LoginItem.isEnabled`).
    public var loginItemWasTried: Bool {
        get { defaults.object(forKey: Key.loginItemWasTried) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.loginItemWasTried) }
    }

    /// True after the first start showed the welcome window.
    public var didFirstStart: Bool {
        get { defaults.object(forKey: Key.didFirstStart) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.didFirstStart) }
    }
}
