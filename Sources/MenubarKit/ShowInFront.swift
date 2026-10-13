import AppKit

extension NSWindow {
    /// Shows the window in front of other apps.
    func showInFront() {
        // The app has no Dock icon, so it is not active by default. Without this, the window opens behind other apps.
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }
}
