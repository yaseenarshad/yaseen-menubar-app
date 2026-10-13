import AppKit

/// The app. It has no menu bar behavior yet: it starts with no Dock icon and stays open.
@MainActor
public final class AppController: NSObject, NSApplicationDelegate {
    /// The same value as `CFBundleIdentifier` in `Support/Info.plist`. A test compares the two.
    public nonisolated static let bundleIdentifier = "com.yaseenarshad.yaseenmenubar"

    /// Starts the app. It does not return.
    public nonisolated static func main() {
        // `main.swift` runs on the main thread, but the compiler does not know that in Swift 5 mode.
        MainActor.assumeIsolated {
            let controller = AppController()

            let app = NSApplication.shared
            app.delegate = controller
            // The same as `LSUIElement`: no Dock icon, also when the binary runs outside the bundle.
            app.setActivationPolicy(.accessory)
            // The delegate of the app is a weak reference.
            withExtendedLifetime(controller) { app.run() }
        }
    }
}
