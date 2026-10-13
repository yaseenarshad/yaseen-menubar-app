import Foundation
@testable import MenubarKit

/// A `UserDefaults` that keeps its values in memory only.
///
/// A real suite (`UserDefaults(suiteName:)`) is not possible in a test: macOS writes a file for it in
/// `~/Library/Preferences`, and writes an empty file again some seconds after `removePersistentDomain`.
/// The tests must leave no file.
final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]

    init() {
        // The name is never used: each call that the app makes is overridden below.
        super.init(suiteName: nil)!
    }

    override func object(forKey defaultName: String) -> Any? { values[defaultName] }
    override func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    override func set(_ value: Int, forKey defaultName: String) { values[defaultName] = value }
    override func set(_ value: Bool, forKey defaultName: String) { values[defaultName] = value }
    override func removeObject(forKey defaultName: String) { values[defaultName] = nil }
}

/// A hotkey center that takes no real hotkey. It refuses the combinations in `refused`.
final class FakeHotKeys: HotKeyRegistering {
    var refused: [HotKeyCombo] = []
    private(set) var registered: HotKeyCombo?

    func register(_ combo: HotKeyCombo) -> Bool {
        // The same as `HotKeyCenter`: a refused call leaves no hotkey.
        registered = refused.contains(combo) ? nil : combo
        return registered != nil
    }

    func unregister() { registered = nil }
}

/// A login item that never talks to macOS.
final class FakeLoginItem: LoginItem {
    struct Refused: LocalizedError {
        var errorDescription: String? { "Operation not permitted" }
    }

    var isAvailable = true
    var isEnabled = false
    var refuses = false
    /// macOS gives no error, but the state does not change (the user must approve the app first).
    var ignores = false
    private(set) var calls: [Bool] = []

    func setEnabled(_ enabled: Bool) throws {
        calls.append(enabled)
        if refuses { throw Refused() }
        if !ignores { isEnabled = enabled }
    }
}
