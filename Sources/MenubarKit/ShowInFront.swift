import AppKit

extension NSWindow {
    /// Shows the window in front of other apps.
    func showInFront() {
        // The app has no Dock icon, so it is not active by default.
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        // macOS can refuse to make the app active. Then the window stays behind the other apps.
        // This call puts the window in front in each case. After it, macOS also makes the app active.
        orderFrontRegardless()
    }
}
