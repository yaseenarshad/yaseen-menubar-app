import AppKit

/// The app. It starts with no Dock icon, puts the arrow in the menu bar, and stays open.
@MainActor
public final class AppController: NSObject, NSApplicationDelegate {
    /// The same value as `CFBundleIdentifier` in `Support/Info.plist`. A test compares the two.
    public nonisolated static let bundleIdentifier = "com.yaseenarshad.yaseenmenubar"

    private var bar: BarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Two copies would put two arrows in the menu bar.
        if AppController.isSecondCopy() {
            NSApp.terminate(nil)
            return
        }
        let bar = BarController()
        bar.start(hidden: true)
        self.bar = bar
    }

    /// True when a copy of the app with the same bundle identifier started before this one.
    private static func isSecondCopy() -> Bool {
        let me = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != me.processIdentifier && !$0.isTerminated }
            .map { ($0.processIdentifier, $0.launchDate) }
        return isSecondCopy(pid: me.processIdentifier, launchDate: me.launchDate, others: others)
    }

    /// The copy that started later quits. With the same or no start time, the higher process id quits.
    /// Thus one copy always stays, also when two start at the same moment.
    nonisolated static func isSecondCopy(pid: pid_t, launchDate: Date?, others: [(pid: pid_t, launchDate: Date?)]) -> Bool {
        others.contains { other in
            if let mine = launchDate, let theirs = other.launchDate, mine != theirs {
                return theirs < mine
            }
            return other.pid < pid
        }
    }

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
