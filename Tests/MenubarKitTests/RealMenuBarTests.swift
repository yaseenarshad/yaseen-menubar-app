import AppKit
import Testing
@testable import MenubarKit

/// The one test with the real menu bar (YAZ-2799). It runs only with `MENUBAR_REAL_TEST=1`:
///
///     MENUBAR_REAL_TEST=1 swift test --filter RealMenuBarTests
///
/// It puts an arrow and a divider in the menu bar for about 3 seconds and removes them, also when a check fails.
/// It uses no mouse and no keyboard. It prints the measured times.
@MainActor @Suite struct RealMenuBarTests {
    nonisolated static let isEnabled = ProcessInfo.processInfo.environment["MENUBAR_REAL_TEST"] == "1"

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

    @Test(.enabled(if: RealMenuBarTests.isEnabled))
    func hideAndShowOnTheRealMenuBar() throws {
        NSApplication.shared.setActivationPolicy(.accessory)

        // AppKit reads the saved positions from the standard defaults. `addSuite` lets it see the suite of this test.
        // The name is fixed, so many runs leave at most one file. The test deletes the file at its end.
        let suiteName = "com.yaseenarshad.yaseenmenubar.realtest"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.addSuite(named: suiteName)
        defer {
            UserDefaults.standard.removeSuite(named: suiteName)
            defaults.removePersistentDomain(forName: suiteName)
            let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/\(suiteName).plist")
            try? FileManager.default.removeItem(at: file)
            // AppKit copies the two positions into the defaults of the test runner.
            UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position YMArrow")
            UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position YMDivider")
        }
        // The status items are gone when this call returns, also when a check fails.
        try checkTheRealMenuBar(defaults: defaults)
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
        let framesTime = try #require(wait {
            guard let arrow = items.arrowFrame, let divider = items.dividerFrame else { return false }
            return divider.maxX == arrow.minX
        })
        let arrow = try #require(items.arrowFrame)
        let thin = try #require(items.dividerFrame)
        let screenLeft = try #require(NSScreen.screens.map(\.frame.minX).min())
        #expect(items.divider.length == DividerLength.thin)
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
        hidden icons \(thinCount) (thin) and \(stretchedCount) (stretched)
        REAL MENU BAR: hide \(String(format: "%.2f", hideTime)) ms, show \(String(format: "%.2f", showTime)) ms, \
        divider frame moved after \(Int(hideFrameTime)) ms (hide) and \(Int(showFrameTime)) ms (show)
        """)
    }
}
