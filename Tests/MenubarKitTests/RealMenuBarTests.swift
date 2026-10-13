import AppKit
import Testing
@testable import MenubarKit

/// The one test with the real menu bar (YAZ-2799). It runs only with `MENUBAR_REAL_TEST=1`:
///
///     MENUBAR_REAL_TEST=1 swift test --filter RealMenuBarTests
///
/// It puts an arrow, a divider, and one test icon in the menu bar for about 3 seconds and removes them, also when a
/// check fails. It uses no mouse and no keyboard. It prints the measured times.
@MainActor @Suite struct RealMenuBarTests {
    static let iconName = "YMRealTestIcon"

    static func positionKey(_ name: String) -> String { "NSStatusItem Preferred Position \(name)" }

    /// Lets the run loop work until the condition is true. Returns the waited milliseconds, or `nil` after the limit.
    func wait(limit: TimeInterval = 1.5, until condition: () -> Bool) -> Double? {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > limit { return nil }
            RunLoop.main.run(until: Date().addingTimeInterval(0.005))
        }
        return Date().timeIntervalSince(start) * 1000
    }

    func milliseconds(_ work: () -> Void) -> Double {
        let duration = ContinuousClock().measure(work)
        return Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["MENUBAR_REAL_TEST"] == "1"))
    func hideAndShowOnTheRealMenuBar() throws {
        NSApplication.shared.setActivationPolicy(.accessory)

        // AppKit reads the saved positions from the standard defaults. `addSuite` lets it see the suite of this test.
        // The name is fixed: macOS keeps an empty file of 42 bytes for a suite, and many runs then leave one file.
        let suiteName = "com.yaseenarshad.yaseenmenubar.realtest"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.addSuite(named: suiteName)
        defer {
            UserDefaults.standard.removeSuite(named: suiteName)
            defaults.removePersistentDomain(forName: suiteName)
            // AppKit copies the positions into the defaults of the test runner, and the second part writes them there.
            for name in [BarItems.arrowName, BarItems.dividerName, RealMenuBarTests.iconName] {
                UserDefaults.standard.removeObject(forKey: RealMenuBarTests.positionKey(name))
            }
        }
        // The status items are gone when each call returns, also when a check fails.
        try checkTheRealMenuBar(defaults: defaults)
        try checkAnIconBetweenTheDividerAndTheArrow()
    }

    private func checkTheRealMenuBar(defaults: UserDefaults) throws {
        let items = BarItems(defaults: defaults)
        defer {
            NSStatusBar.system.removeStatusItem(items.arrow)
            NSStatusBar.system.removeStatusItem(items.divider)
        }
        let controller = BarController(
            items: items, autoHide: AutoHide(), watcher: NewIconWatcher(),
            hiddenIconCount: NewIconWatcher.hiddenIconCount, uptime: { ProcessInfo.processInfo.systemUptime }
        )
        controller.hideAfterSeconds = 0
        controller.start(hidden: false)

        // S33: the first start writes the two positions.
        #expect(defaults.double(forKey: "NSStatusItem Preferred Position YMArrow") == 420)
        #expect(defaults.double(forKey: "NSStatusItem Preferred Position YMDivider") == 430)

        // S37: macOS made real windows. The frames arrive about 150 ms after the creation.
        // The divider lands directly on the left of the arrow.
        let framesTime = try #require(wait {
            guard let arrow = items.arrowFrame, let divider = items.dividerFrame else { return false }
            return BarLayout.dividerTouchesArrow(dividerFrame: divider, arrowFrame: arrow)
        }, "arrow \(String(describing: items.arrowFrame)), divider \(String(describing: items.dividerFrame))")
        let arrow = try #require(items.arrowFrame)
        let thin = try #require(items.dividerFrame)
        let screenLeft = try #require(NSScreen.screens.map(\.frame.minX).min())
        #expect(items.divider.length == DividerLength.thin)
        // S41: the divider shows nothing, and the gap on the left of the arrow is the minimum of macOS.
        #expect(items.divider.button?.image == nil)
        #expect(items.divider.button?.title == "")
        #expect(thin.width <= 17)
        let dividerItem = items.divider
        #expect(items.arrow.button?.image?.accessibilityDescription == "Hide the icons")

        // The real windows of the other icons still move for a short time after two new icons arrive.
        // The app counts 2 seconds after its start at the earliest. That first call of the window list is slow.
        _ = wait(limit: 0.5) { false }
        var thinCount = 0
        let firstCountTime = milliseconds { thinCount = NewIconWatcher.hiddenIconCount(dividerFrame: thin) }

        // S2: hide.
        let hideTime = milliseconds { controller.toggle() }
        #expect(items.divider.length == DividerLength.stretched)
        #expect(items.arrow.button?.image?.accessibilityDescription == "Show the hidden icons")
        let hideFrameTime = try #require(wait { (items.dividerFrame?.minX ?? thin.minX) < screenLeft - 1000 })
        let stretched = try #require(items.dividerFrame)
        #expect(stretched.minX < screenLeft - 1000)
        #expect(items.arrowFrame == arrow)
        // The divider touched the arrow, so the hide made no new divider.
        #expect(items.divider === dividerItem)
        #expect(BarLayout.dividerTouchesArrow(dividerFrame: stretched, arrowFrame: arrow))
        #expect(items.divider.button?.image == nil)
        let stretchedCount = NewIconWatcher.hiddenIconCount(dividerFrame: stretched)
        #expect(stretchedCount == thinCount)

        // S36: the same state again writes no image.
        let image = items.arrow.button?.image
        var sameState = BarModel()
        sameState.hide(hiddenCount: 0)
        items.render(sameState)
        #expect(items.arrow.button?.image === image)

        // S1: show.
        let showTime = milliseconds { controller.toggle() }
        #expect(items.divider.length == DividerLength.thin)
        #expect(items.arrow.button?.image?.accessibilityDescription == "Hide the icons")
        let showFrameTime = try #require(wait { items.dividerFrame == thin })
        #expect(items.arrowFrame == arrow)

        // A click must change the menu bar in less than one frame of the display.
        #expect(hideTime < 16)
        #expect(showTime < 16)
        print("""
        REAL MENU BAR: arrow \(arrow), thin divider \(thin), stretched divider \(stretched)
        REAL MENU BAR: frames after \(Int(framesTime)) ms, first count \(String(format: "%.2f", firstCountTime)) ms, \
        hidden icons \(thinCount) (thin) and \(stretchedCount) (stretched), \
        status windows of all displays \(WindowList.frames(at: .statusWindow, onScreenOnly: false).count), displays \(NSScreen.screens.count)
        REAL MENU BAR: hide \(String(format: "%.2f", hideTime)) ms, show \(String(format: "%.2f", showTime)) ms, \
        divider frame moved after \(Int(hideFrameTime)) ms (hide) and \(Int(showFrameTime)) ms (show)
        REAL MENU BAR: menu open: \(AutoHide.menuIsOpen()), pointer in a menu bar: \(AutoHide.pointerIsInMenuBar())
        """)
    }

    /// S16, S42, S17: an icon is between the divider and the arrow. The hide makes the divider again directly on the
    /// left of the arrow, so the icon hides too. A test cannot drag, so the saved positions put a test icon there.
    private func checkAnIconBetweenTheDividerAndTheArrow() throws {
        // The same defaults as the app: AppKit reads the positions there, and the repair writes one there.
        // A larger position is further left: the divider (436), the test icon (432), the arrow (420).
        let defaults = UserDefaults.standard
        defaults.set(420, forKey: RealMenuBarTests.positionKey(BarItems.arrowName))
        defaults.set(436, forKey: RealMenuBarTests.positionKey(BarItems.dividerName))
        defaults.set(432, forKey: RealMenuBarTests.positionKey(RealMenuBarTests.iconName))

        let items = BarItems(defaults: defaults)
        let icon = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        icon.autosaveName = RealMenuBarTests.iconName
        icon.button?.title = "•"
        defer {
            NSStatusBar.system.removeStatusItem(icon)
            NSStatusBar.system.removeStatusItem(items.arrow)
            NSStatusBar.system.removeStatusItem(items.divider)
        }
        let controller = BarController(
            items: items, autoHide: AutoHide(), watcher: NewIconWatcher(),
            hiddenIconCount: NewIconWatcher.hiddenIconCount, uptime: { ProcessInfo.processInfo.systemUptime }
        )
        controller.hideAfterSeconds = 0
        controller.start(hidden: false)

        func iconFrame() -> CGRect { icon.button?.window?.frame ?? .zero }
        func frames() -> String {
            "arrow \(String(describing: items.arrowFrame)), icon \(iconFrame()), divider \(String(describing: items.dividerFrame))"
        }

        // The start: the icon is between the divider and the arrow.
        _ = try #require(wait {
            guard let arrow = items.arrowFrame, let divider = items.dividerFrame else { return false }
            return iconFrame().maxX == arrow.minX && divider.maxX == iconFrame().minX
        }, "\(frames())")
        let arrow = try #require(items.arrowFrame)
        let between = try #require(items.dividerFrame)
        let screenLeft = try #require(NSScreen.screens.map(\.frame.minX).min())
        #expect(!BarLayout.dividerTouchesArrow(dividerFrame: between, arrowFrame: arrow))
        // The real windows of the other icons still move for a short time after new icons arrive.
        _ = wait(limit: 0.5) { false }
        let countBefore = NewIconWatcher.hiddenIconCount(dividerFrame: between)
        let oldDivider = items.divider

        // The hide makes the divider again with the position of the arrow + 10. The window list then has one more
        // icon on the left of the divider: the test icon.
        let hideTime = milliseconds { controller.toggle() }
        #expect(items.divider !== oldDivider)
        #expect(items.divider.length == DividerLength.stretched)
        #expect(defaults.double(forKey: RealMenuBarTests.positionKey(BarItems.dividerName)) == 430)
        let hideFrameTime = try #require(wait {
            guard let divider = items.dividerFrame, divider.minX < screenLeft - 1000 else { return false }
            return NewIconWatcher.hiddenIconCount(dividerFrame: divider) == countBefore + 1
        }, "\(frames())")
        let stretched = try #require(items.dividerFrame)
        #expect(BarLayout.dividerTouchesArrow(dividerFrame: stretched, arrowFrame: arrow))
        #expect(items.arrowFrame == arrow)
        let hiddenIcon = iconFrame()

        // The show: the divider touches the arrow, and the icon is on the left of the divider.
        controller.toggle()
        let showFrameTime = try #require(wait {
            guard let now = items.arrowFrame, let divider = items.dividerFrame, divider.width < 100 else { return false }
            return BarLayout.dividerTouchesArrow(dividerFrame: divider, arrowFrame: now) && iconFrame().maxX == divider.minX
        }, "\(frames())")
        let thin = try #require(items.dividerFrame)
        #expect(items.arrowFrame == arrow)
        #expect(NewIconWatcher.hiddenIconCount(dividerFrame: thin) == countBefore + 1)
        print("""
        REAL MENU BAR, AN ICON BETWEEN: before the hide: divider \(between), arrow \(arrow); \
        hidden icons \(countBefore) before and \(countBefore + 1) after
        REAL MENU BAR, AN ICON BETWEEN: hide with the repair \(String(format: "%.2f", hideTime)) ms, \
        new divider frame after \(Int(hideFrameTime)) ms: \(stretched), the icon while hidden \(hiddenIcon)
        REAL MENU BAR, AN ICON BETWEEN: after the show (\(Int(showFrameTime)) ms): divider \(thin), icon \(iconFrame())
        """)
    }
}
