import AppKit

/// The app. It starts with no Dock icon, puts the arrow in the menu bar, and joins the parts.
@MainActor
public final class AppController: NSObject, NSApplicationDelegate {
    /// The same value as `CFBundleIdentifier` in `Support/Info.plist`. A test compares the two.
    public nonisolated static let bundleIdentifier = "com.yaseenarshad.yaseenmenubar"

    /// The menu rows hold the menu object as a weak target, so the app keeps it.
    let menu = ArrowMenu()
    private(set) var settings: SettingsModel?

    private var bar: BarController?
    private var welcome: WelcomeWindowController?
    private var settingsWindow: SettingsWindowController?
    private let hotKeys = HotKeyCenter()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Two copies would put two arrows in the menu bar.
        if AppController.isSecondCopy() {
            NSApp.terminate(nil)
            return
        }
        let store = SettingsStore(defaults: .standard)
        let bar = BarController()
        // The hotkey does the same as a click on the arrow.
        hotKeys.onHotKey = { [weak bar] in MainActor.assumeIsolated { bar?.toggle() } }
        start(
            bar: bar,
            store: store,
            settings: SettingsModel(store: store, hotKeys: hotKeys, loginItem: SystemLoginItem()),
            welcome: WelcomeWindowController()
        )
    }

    /// Joins the parts and starts the bar. A test calls this with fake parts.
    func start(bar: BarController, store: SettingsStore, settings: SettingsModel, welcome: WelcomeWindowController) {
        self.bar = bar
        self.settings = settings
        self.welcome = welcome

        bar.hideAfterSeconds = settings.hideAfterSeconds
        settings.onHideAfterChanged = { [weak bar] in bar?.hideAfterSeconds = $0 }
        settings.registerHotKey()
        settings.registerLoginItemAtFirstStart()

        menu.onSettings = { [weak self] in self?.showSettings() }
        menu.onHowTo = { [weak welcome] in welcome?.show() }
        menu.onQuit = { NSApp.terminate(nil) }
        bar.menu = menu.menu

        // The icons stay shown while the welcome window is open. The user needs them to drag.
        welcome.onOpen = { [weak bar] in bar?.holdsOpen = true }
        welcome.onClose = { [weak bar] in bar?.holdsOpen = false }

        if store.didFirstStart {
            bar.start(hidden: true)
        } else {
            welcome.show()
            bar.start(hidden: false)
            store.didFirstStart = true
        }
    }

    /// The window is made at the first "Settings…" and kept, so there is never a second one.
    private func showSettings() {
        guard let settings = settings else { return }
        if settingsWindow == nil { settingsWindow = SettingsWindowController(model: settings) }
        settingsWindow?.show()
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
