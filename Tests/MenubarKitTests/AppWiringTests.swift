import AppKit
import Carbon.HIToolbox
import Testing
@testable import MenubarKit

/// The app joins the bar, the settings, the menu, and the welcome window (YAZ-2799 to YAZ-2801).
/// Each part is a fake or gets fake inputs, so nothing touches the real menu bar and no window comes on the screen.
@MainActor
@Suite struct AppWiringTests {
    let clock = FakeClock()
    let items = FakeItems()
    let hotKeys = FakeHotKeys()
    let loginItem = FakeLoginItem()
    let store = SettingsStore(defaults: MemoryDefaults())
    let app = AppController()
    let shown = Shown()

    @MainActor final class Shown {
        var welcomeWindows = 0
    }

    /// Starts the app with the fakes. Returns the welcome window, so a test can close it.
    @discardableResult
    func start() -> WelcomeWindowController {
        let clock = clock, shown = shown
        let bar = BarController(
            items: items,
            autoHide: AutoHide(schedule: clock.schedule, pointerIsInMenuBar: { false }, menuIsOpen: { false }),
            watcher: NewIconWatcher(center: NotificationCenter(), schedule: clock.schedule),
            hiddenIconCount: { _ in 13 },
            uptime: { clock.now }
        )
        let settings = SettingsModel(store: store, hotKeys: hotKeys, loginItem: loginItem)
        let welcome = WelcomeWindowController(bartenderIsRunning: { false }) { _ in shown.welcomeWindows += 1 }
        app.start(bar: bar, store: store, settings: settings, welcome: welcome)
        return welcome
    }

    // S11, S38, S39
    @Test func theFirstStartShowsTheIconsAndTheWelcomeWindow() {
        let welcome = start()
        #expect(items.isHidden == false)
        #expect(shown.welcomeWindows == 1)
        #expect(store.didFirstStart)

        // The icons stay while the window is open. The user needs them to drag.
        clock.advance(by: 120)
        #expect(items.isHidden == false)

        // "Done" closes the window. Then the delay starts.
        welcome.content.onDone()
        clock.advance(by: 9)
        #expect(items.isHidden == false)
        clock.advance(by: 1)
        #expect(items.isHidden == true)
    }

    // S10
    @Test func aLaterStartHidesTheIconsAndShowsNoWindow() {
        store.didFirstStart = true
        start()
        #expect(items.isHidden == true)
        #expect(shown.welcomeWindows == 0)
    }

    // S9, S30
    @Test func theStoredDelayReachesTheBarAndSoDoesAChangeInTheSettings() {
        store.didFirstStart = true
        store.hideAfterSeconds = 30
        start()

        items.onClick?(false)
        clock.advance(by: 29)
        #expect(items.isHidden == false)

        app.settings?.setHideAfterSeconds(5)
        clock.advance(by: 4)
        #expect(items.isHidden == false)
        clock.advance(by: 1)
        #expect(items.isHidden == true)
    }

    // S3, S40
    @Test func theArrowHasTheMenuAndHowToOpensTheWelcomeWindow() {
        store.didFirstStart = true
        start()

        items.onClick?(true)
        #expect(items.openedMenus.map { $0.items.map(\.title) } == [["Settings…", "How to hide an icon", "", "Quit Yaseen Menubar"]])

        app.menu.onHowTo()
        #expect(shown.welcomeWindows == 1)
        #expect(items.isHidden == false)
        clock.advance(by: 120)
        #expect(items.isHidden == false)
    }

    // S27, S29
    @Test func theStartRegistersTheStoredHotKeyAndTheLoginItem() {
        let combo = HotKeyCombo(keyCode: UInt32(kVK_ANSI_B), modifiers: [.control, .option, .command])
        store.hotKey = combo
        start()
        #expect(hotKeys.registered == combo)
        #expect(loginItem.calls == [true])
        #expect(store.loginItemWasTried)
    }

    // Decision 11: there is no hotkey until the user records one.
    @Test func theStartRegistersNoHotKeyWhenNoneIsStored() {
        start()
        #expect(hotKeys.registered == nil)
    }
}
