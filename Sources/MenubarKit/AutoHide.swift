import AppKit

/// Hides the icons again after a delay. It owns one wait, and only while the icons show.
@MainActor final class AutoHide {
    /// The time between two checks while the pointer is in the menu bar or a menu is open.
    static let recheckSeconds: TimeInterval = 2

    var onHide: (() -> Void)?

    private let schedule: Schedule
    private let pointerIsInMenuBar: @MainActor () -> Bool
    private let menuIsOpen: @MainActor () -> Bool
    private var cancel: Cancel?

    init(
        schedule: @escaping Schedule,
        pointerIsInMenuBar: @escaping @MainActor () -> Bool,
        menuIsOpen: @escaping @MainActor () -> Bool
    ) {
        self.schedule = schedule
        self.pointerIsInMenuBar = pointerIsInMenuBar
        self.menuIsOpen = menuIsOpen
    }

    /// The real clock and the real checks.
    convenience init() {
        self.init(schedule: RealClock.schedule, pointerIsInMenuBar: AutoHide.pointerIsInMenuBar, menuIsOpen: AutoHide.menuIsOpen)
    }

    /// Starts the delay again. 0 seconds is "Never": no wait.
    func start(seconds: Int) {
        stop()
        if seconds > 0 { wait(TimeInterval(seconds)) }
    }

    func stop() {
        cancel?()
        cancel = nil
    }

    private func wait(_ seconds: TimeInterval) {
        cancel = schedule(seconds) { [weak self] in self?.delayEnded() }
    }

    private func delayEnded() {
        cancel = nil
        // The user works in the menu bar. A hide now would move the icons under the pointer or close a menu.
        if pointerIsInMenuBar() || menuIsOpen() {
            wait(AutoHide.recheckSeconds)
        } else {
            onHide?()
        }
    }
}

// Each check reads one value one time. Nothing watches the pointer.
extension AutoHide {
    static func pointerIsInMenuBar() -> Bool {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            BarLayout.menuBarBand(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                  statusBarThickness: NSStatusBar.system.thickness).contains(pointer)
        }
    }

    /// An open menu is a window on the screen at the level of menus. This is true for the menus of all apps.
    static func menuIsOpen() -> Bool {
        !WindowList.frames(at: .popUpMenuWindow, onScreenOnly: true).isEmpty
    }
}
