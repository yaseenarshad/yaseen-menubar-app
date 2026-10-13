import Foundation

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
