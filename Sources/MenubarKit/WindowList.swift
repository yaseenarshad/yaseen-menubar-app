import CoreGraphics
import Foundation

/// Reads the window list of the window server. It reads only the level and the bounds of a window.
/// These need no permission. The name of a window needs Screen Recording, so this code never reads it.
enum WindowList {
    /// The frames of the windows at one level. The zero is at the top of the main screen, and y grows down.
    static func frames(at level: CGWindowLevelKey, onScreenOnly: Bool) -> [CGRect] {
        let options: CGWindowListOption = onScreenOnly ? .optionOnScreenOnly : .optionAll
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        let wanted = Int(CGWindowLevelForKey(level))
        return windows.compactMap { window in
            guard window[kCGWindowLayer as String] as? Int == wanted,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }
    }
}
