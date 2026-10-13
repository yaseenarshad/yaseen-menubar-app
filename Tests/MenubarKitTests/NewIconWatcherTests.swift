import AppKit
import Testing
@testable import MenubarKit

/// The one-time check after an app start (YAZ-2800). A private notification center and a fake clock drive it.
@MainActor @Suite struct NewIconWatcherTests {
    let clock = FakeClock()
    let center = NotificationCenter()
    let checks = Counter()

    @MainActor final class Counter { var count = 0 }

    func makeWatcher() -> NewIconWatcher {
        let checks = checks
        let watcher = NewIconWatcher(center: center, schedule: clock.schedule)
        watcher.onCheck = { checks.count += 1 }
        return watcher
    }

    func launchAnApp() {
        center.post(name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    }

    // S21: an app needs time to make its icon. The check comes 2 seconds after the launch, one time.
    @Test func aLaunchGivesOneCheckAfterTwoSeconds() {
        let watcher = makeWatcher()
        watcher.start()
        launchAnApp()

        clock.advance(by: 1.9)
        #expect(checks.count == 0)
        clock.advance(by: 0.1)
        #expect(checks.count == 1)

        // No polling: nothing more happens until the next launch.
        #expect(clock.pendingCount == 0)
        clock.advance(by: 3600)
        #expect(checks.count == 1)
    }

    @Test func withNoLaunchThereIsNoWait() {
        let watcher = makeWatcher()
        watcher.start()
        #expect(clock.pendingCount == 0)
        #expect(!watcher.isWaiting)
    }

    // At login many apps start. They share one wait and one check.
    @Test func launchesCloseTogetherGiveOneCheck() {
        let watcher = makeWatcher()
        watcher.start()
        launchAnApp()
        clock.advance(by: 1)
        launchAnApp()
        #expect(clock.pendingCount == 1)

        clock.advance(by: 1.9)
        #expect(checks.count == 0)
        clock.advance(by: 0.1)
        #expect(checks.count == 1)
        #expect(clock.pendingCount == 0)
    }

    // The app asks for a check itself after its own start and after a repair of the divider.
    @Test func checkSoonGivesOneCheckWithNoLaunch() {
        let watcher = makeWatcher()
        watcher.checkSoon()
        #expect(watcher.isWaiting)
        clock.advance(by: 2)
        #expect(checks.count == 1)
        #expect(!watcher.isWaiting)
    }

    @Test func aLaunchBeforeStartDoesNothing() {
        _ = makeWatcher()
        launchAnApp()
        #expect(clock.pendingCount == 0)
    }
}
