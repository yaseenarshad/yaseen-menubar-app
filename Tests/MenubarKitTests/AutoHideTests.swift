import Testing
@testable import MenubarKit

/// The delay that hides the icons again (YAZ-2800). A fake clock and fake checks drive it.
@MainActor @Suite struct AutoHideTests {
    let clock = FakeClock()
    let world = World()

    /// What the two checks answer, and what the delay did.
    @MainActor final class World {
        var pointerIsInMenuBar = false
        var menuIsOpen = false
        var checkCount = 0
        var hideCount = 0
    }

    func makeAutoHide() -> AutoHide {
        let world = world
        let autoHide = AutoHide(
            schedule: clock.schedule,
            pointerIsInMenuBar: { world.checkCount += 1; return world.pointerIsInMenuBar },
            menuIsOpen: { world.checkCount += 1; return world.menuIsOpen }
        )
        autoHide.onHide = { world.hideCount += 1 }
        return autoHide
    }

    // S5
    @Test func theIconsHideWhenTheDelayEnds() {
        let autoHide = makeAutoHide()
        autoHide.start(seconds: 10)
        #expect(autoHide.isWaiting)

        clock.advance(by: 9.9)
        #expect(world.hideCount == 0)
        // No monitor of the pointer: the checks run only when the delay ends.
        #expect(world.checkCount == 0)

        clock.advance(by: 0.1)
        #expect(world.hideCount == 1)
        #expect(!autoHide.isWaiting)
        #expect(clock.pendingCount == 0)
    }

    // S6
    @Test func thePointerInTheMenuBarMakesTheDelayWaitTwoSeconds() {
        let autoHide = makeAutoHide()
        world.pointerIsInMenuBar = true
        autoHide.start(seconds: 10)

        clock.advance(by: 10)
        #expect(world.hideCount == 0)
        #expect(autoHide.isWaiting)

        // The pointer stays for a long time. The delay checks again each 2 seconds with one wait.
        clock.advance(by: 60)
        #expect(world.hideCount == 0)
        #expect(clock.pendingCount == 1)

        world.pointerIsInMenuBar = false
        clock.advance(by: 1.9)
        #expect(world.hideCount == 0)
        clock.advance(by: 0.1)
        #expect(world.hideCount == 1)
        #expect(clock.pendingCount == 0)
    }

    // S7: a menu must never close because of the app.
    @Test func anOpenMenuMakesTheDelayWaitTwoSeconds() {
        let autoHide = makeAutoHide()
        world.menuIsOpen = true
        autoHide.start(seconds: 5)

        clock.advance(by: 5)
        #expect(world.hideCount == 0)
        clock.advance(by: 2)
        #expect(world.hideCount == 0)

        world.menuIsOpen = false
        clock.advance(by: 2)
        #expect(world.hideCount == 1)
    }

    // S8
    @Test func theDelayNeverMakesNoWait() {
        let autoHide = makeAutoHide()
        autoHide.start(seconds: 0)
        #expect(!autoHide.isWaiting)
        #expect(clock.pendingCount == 0)

        clock.advance(by: 3600)
        #expect(world.hideCount == 0)
    }

    // S9
    @Test func aNewStartReplacesTheOldWait() {
        let autoHide = makeAutoHide()
        autoHide.start(seconds: 10)
        clock.advance(by: 4)
        autoHide.start(seconds: 30)
        #expect(clock.pendingCount == 1)

        clock.advance(by: 29.9)
        #expect(world.hideCount == 0)
        clock.advance(by: 0.1)
        #expect(world.hideCount == 1)
    }

    @Test func stopEndsTheWait() {
        let autoHide = makeAutoHide()
        autoHide.start(seconds: 10)
        autoHide.stop()
        #expect(!autoHide.isWaiting)
        #expect(clock.pendingCount == 0)

        // Also a wait of 2 seconds for the pointer stops.
        world.pointerIsInMenuBar = true
        autoHide.start(seconds: 10)
        clock.advance(by: 10)
        autoHide.stop()
        world.pointerIsInMenuBar = false
        clock.advance(by: 60)
        #expect(world.hideCount == 0)
        #expect(clock.pendingCount == 0)
    }
}
