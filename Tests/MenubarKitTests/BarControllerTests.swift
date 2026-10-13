import AppKit
import Testing
@testable import MenubarKit

/// The status items for the tests. They record what the controller did. Nothing touches the real menu bar.
@MainActor final class FakeItems: StatusItems {
    var onClick: ((Bool) -> Void)?
    /// The frames of the probe on the built-in display: the divider is directly on the left of the arrow.
    var arrowFrame: CGRect? = CGRect(x: 1245, y: 1084, width: 26, height: 33)
    var dividerFrame: CGRect? = CGRect(x: 1221, y: 1084, width: 24, height: 33)

    private(set) var rendered: [BarModel] = []
    private(set) var openedMenus: [NSMenu] = []
    /// "show", "hide", and "repair", in the order of the calls.
    private(set) var log: [String] = []

    func render(_ model: BarModel) {
        rendered.append(model)
        log.append(model.isHidden ? "hide" : "show")
    }

    func putDividerLeftOfArrow() {
        log.append("repair")
        // A new status item has no correct frame for about 150 ms.
        dividerFrame = nil
    }

    func open(_ menu: NSMenu) { openedMenus.append(menu) }

    var isHidden: Bool? { rendered.last?.isHidden }
    var hasDot: Bool? { rendered.last?.hasNewIcon }
}

/// The controller with fake status items, a fake clock, and fake checks (YAZ-2799, YAZ-2800).
@MainActor @Suite struct BarControllerTests {
    let clock = FakeClock()
    let center = NotificationCenter()
    let items = FakeItems()
    let world = World()

    @MainActor final class World {
        var pointerIsInMenuBar = false
        var menuIsOpen = false
        var hiddenCount = 13
        var countCalls = 0
    }

    func makeController() -> BarController {
        let world = world, clock = clock
        return BarController(
            items: items,
            autoHide: AutoHide(schedule: clock.schedule,
                               pointerIsInMenuBar: { world.pointerIsInMenuBar },
                               menuIsOpen: { world.menuIsOpen }),
            watcher: NewIconWatcher(center: center, schedule: clock.schedule),
            hiddenIconCount: { _ in world.countCalls += 1; return world.hiddenCount },
            uptime: { clock.now }
        )
    }

    /// A controller that started hidden a long time ago, so no wait is active and a new icon gives a dot.
    func makeHiddenController() -> BarController {
        let controller = makeController()
        controller.start(hidden: true)
        clock.advance(by: 300)
        return controller
    }

    func launchAnApp() {
        center.post(name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        clock.advance(by: 2)
    }

    // MARK: Hide and show (YAZ-2799)

    // S1, S2
    @Test func aLeftClickShowsAndTheNextLeftClickHides() {
        let controller = makeHiddenController()
        _ = controller
        items.onClick?(false)
        #expect(items.isHidden == false)
        items.onClick?(false)
        #expect(items.isHidden == true)
    }

    // S3
    @Test func aRightClickOpensTheMenuAndChangesNoState() {
        let controller = makeHiddenController()
        let menu = NSMenu()
        controller.menu = menu
        let rendersBefore = items.rendered.count

        items.onClick?(true)
        #expect(items.openedMenus == [menu])
        #expect(items.rendered.count == rendersBefore)
        #expect(clock.pendingCount == 0)
    }

    @Test func aRightClickWithNoMenuDoesNothing() {
        let controller = makeHiddenController()
        _ = controller
        let rendersBefore = items.rendered.count
        items.onClick?(true)
        #expect(items.openedMenus.isEmpty)
        #expect(items.rendered.count == rendersBefore)
    }

    // S4
    @Test func toggleIsTheSameAsALeftClick() {
        let controller = makeHiddenController()
        controller.toggle()
        #expect(items.isHidden == false)
        controller.toggle()
        #expect(items.isHidden == true)
    }

    // S10, and the rule "no timer while the icons are hidden".
    @Test func aNormalStartHidesAtOnceAndLeavesNoWait() {
        let controller = makeController()
        controller.start(hidden: true)
        #expect(items.log == ["hide"])

        // The one check of the start ends after 2 seconds. Then nothing is active.
        clock.advance(by: 2)
        #expect(clock.pendingCount == 0)
        clock.advance(by: 3600)
        #expect(items.log == ["hide"])
        #expect(clock.pendingCount == 0)
    }

    // S11
    @Test func theFirstStartShowsTheIcons() {
        let controller = makeController()
        controller.start(hidden: false)
        #expect(items.log == ["show"])
    }

    @Test func nothingHappensBeforeTheStart() {
        let controller = makeController()
        controller.hideAfterSeconds = 5
        controller.holdsOpen = true
        controller.holdsOpen = false
        controller.toggle()
        #expect(items.rendered.isEmpty)
        #expect(clock.pendingCount == 0)
    }

    // S17
    @Test func aDividerOnTheRightOfTheArrowIsMadeAgainBeforeTheHide() {
        let controller = makeHiddenController()
        controller.toggle()
        // The user dragged the divider to the right of the arrow.
        items.dividerFrame = CGRect(x: 1271, y: 1084, width: 24, height: 33)

        controller.toggle()
        #expect(items.log.suffix(2) == ["repair", "hide"])
    }

    @Test func aDividerThatTouchesTheArrowIsNotMadeAgain() {
        let controller = makeHiddenController()
        controller.toggle()
        controller.toggle()
        #expect(!items.log.contains("repair"))
    }

    // S16, S42: the user dropped an icon directly on the left of the arrow, and macOS put it on the right of the divider.
    @Test func anIconBetweenTheDividerAndTheArrowIsHiddenToo() {
        let controller = makeHiddenController()
        controller.toggle()
        // An icon of 38 points is between the divider and the arrow.
        items.dividerFrame = CGRect(x: 1183, y: 1084, width: 24, height: 33)

        controller.toggle()
        #expect(items.log.suffix(2) == ["repair", "hide"])

        // The new divider is directly on the left of the arrow. The icon is on its left now.
        world.hiddenCount = 14
        items.dividerFrame = CGRect(x: -3771, y: 1084, width: 5016, height: 33)
        clock.advance(by: 2)
        #expect(items.isHidden == true)
        // The user put the icon there. It is not a new icon, so the arrow shows no dot.
        #expect(items.hasDot == false)
        #expect(clock.pendingCount == 0)

        // The count of the repair is the highest count now. Only one more icon is a new icon.
        launchAnApp()
        #expect(items.hasDot == false)
        world.hiddenCount = 15
        launchAnApp()
        #expect(items.hasDot == true)
    }

    // The user shows the icons again before the check of the repair. The check must not hide them.
    @Test func aShowBeforeTheCheckOfTheRepairStaysShown() {
        let controller = makeHiddenController()
        controller.hideAfterSeconds = 0
        controller.toggle()
        items.dividerFrame = CGRect(x: 1183, y: 1084, width: 24, height: 33)
        controller.toggle()
        controller.toggle()

        items.dividerFrame = CGRect(x: 1221, y: 1084, width: 24, height: 33)
        clock.advance(by: 2)
        #expect(items.isHidden == false)
        #expect(items.hasDot == false)
    }

    // The number of a different icon can keep it between them. The arrow is on the screen, so the icons stay hidden.
    @Test func theIconsStayHiddenWhenAnIconIsStillBetweenAfterTheRepair() {
        let controller = makeHiddenController()
        controller.toggle()
        items.dividerFrame = CGRect(x: 1183, y: 1084, width: 24, height: 33)
        controller.toggle()

        items.dividerFrame = CGRect(x: -3809, y: 1084, width: 5016, height: 33)
        clock.advance(by: 2)
        #expect(items.isHidden == true)
        #expect(clock.pendingCount == 0)
    }

    // The frames are not correct directly after the start. The controller must not repair from wrong frames.
    @Test func noRepairWhenTheFramesAreNotReady() {
        items.arrowFrame = nil
        items.dividerFrame = nil
        let controller = makeController()
        controller.start(hidden: true)
        #expect(items.log == ["hide"])
        #expect(world.countCalls == 0)
    }

    // S17: also the hide of the delay checks the divider.
    @Test func theDelayAlsoRepairsTheDividerBeforeItHides() {
        let controller = makeHiddenController()
        controller.toggle()
        items.dividerFrame = CGRect(x: 1271, y: 1084, width: 24, height: 33)
        clock.advance(by: 10)
        #expect(items.log.suffix(2) == ["repair", "hide"])
    }

    // The arrow must never stay off the screen. The check comes 2 seconds after a hide with no correct frames.
    @Test func theIconsShowAgainWhenTheArrowIsOffTheScreenAfterTheStart() {
        let controller = makeController()
        controller.start(hidden: true)
        // The frames arrive. A wrong divider pushed the arrow off the screen, so the arrow has no frame in a menu bar.
        items.arrowFrame = nil
        items.dividerFrame = CGRect(x: -3745, y: 1084, width: 5016, height: 33)

        clock.advance(by: 2)
        #expect(items.log == ["hide", "show"])
    }

    @Test func theIconsShowAgainWhenTheRepairDidNotWork() {
        let controller = makeHiddenController()
        controller.toggle()
        items.dividerFrame = CGRect(x: 1271, y: 1084, width: 24, height: 33)
        controller.toggle()
        #expect(items.isHidden == true)

        // The new divider is on the right of the arrow again.
        items.arrowFrame = CGRect(x: -3771, y: 1084, width: 26, height: 33)
        items.dividerFrame = CGRect(x: -3745, y: 1084, width: 5016, height: 33)
        clock.advance(by: 2)
        #expect(items.isHidden == false)

        // The delay must not hide again: each hide would remove and make the divider one more time.
        #expect(clock.pendingCount == 0)
        clock.advance(by: 3600)
        #expect(items.isHidden == false)
        #expect(items.log.filter { $0 == "repair" }.count == 1)

        // A click tries again.
        items.dividerFrame = CGRect(x: 1271, y: 1084, width: 24, height: 33)
        items.arrowFrame = CGRect(x: 1245, y: 1084, width: 26, height: 33)
        controller.toggle()
        #expect(items.log.suffix(2) == ["repair", "hide"])
    }

    @Test func theIconsStayHiddenWhenTheRepairWorked() {
        let controller = makeHiddenController()
        controller.toggle()
        items.dividerFrame = CGRect(x: 1271, y: 1084, width: 24, height: 33)
        controller.toggle()

        items.dividerFrame = CGRect(x: -3771, y: 1084, width: 5016, height: 33)
        clock.advance(by: 2)
        #expect(items.isHidden == true)
        #expect(clock.pendingCount == 0)
    }

    // S36: the controller gives the status items a state only when the state changed.
    @Test func anAppStartThatChangesNothingGivesNoRender() {
        let controller = makeHiddenController()
        _ = controller
        let rendersBefore = items.rendered.count
        launchAnApp()
        #expect(items.rendered.count == rendersBefore)
    }

    // MARK: The delay (YAZ-2800)

    // S5
    @Test func theIconsHideAgainAfterTenSeconds() {
        let controller = makeHiddenController()
        controller.toggle()
        clock.advance(by: 9.9)
        #expect(items.isHidden == false)
        clock.advance(by: 0.1)
        #expect(items.isHidden == true)
        #expect(clock.pendingCount == 0)
    }

    // S6, S7
    @Test func theDelayWaitsForThePointerAndForAnOpenMenu() {
        let controller = makeHiddenController()
        controller.toggle()
        world.pointerIsInMenuBar = true
        clock.advance(by: 30)
        #expect(items.isHidden == false)

        world.pointerIsInMenuBar = false
        world.menuIsOpen = true
        clock.advance(by: 30)
        #expect(items.isHidden == false)

        world.menuIsOpen = false
        clock.advance(by: 2)
        #expect(items.isHidden == true)
    }

    // S8
    @Test func theDelayNeverKeepsTheIconsUntilAClick() {
        let controller = makeHiddenController()
        controller.hideAfterSeconds = 0
        controller.toggle()
        #expect(clock.pendingCount == 0)
        clock.advance(by: 3600)
        #expect(items.isHidden == false)

        controller.toggle()
        #expect(items.isHidden == true)
    }

    // S9
    @Test func aNewDelayWhileTheIconsShowStartsTheWaitAgain() {
        let controller = makeHiddenController()
        controller.toggle()
        clock.advance(by: 4)
        controller.hideAfterSeconds = 30

        clock.advance(by: 29.9)
        #expect(items.isHidden == false)
        clock.advance(by: 0.1)
        #expect(items.isHidden == true)
    }

    @Test func aNewDelayWhileTheIconsAreHiddenStartsNoWait() {
        let controller = makeHiddenController()
        controller.hideAfterSeconds = 5
        #expect(clock.pendingCount == 0)
    }

    // A click while the delay runs hides at once and stops the wait.
    @Test func aClickStopsTheDelay() {
        let controller = makeHiddenController()
        controller.toggle()
        clock.advance(by: 3)
        controller.toggle()
        #expect(items.isHidden == true)
        #expect(clock.pendingCount == 0)
    }

    // The first start: the delay runs, also with no welcome window.
    @Test func theDelayRunsAfterAShownStart() {
        let controller = makeController()
        controller.start(hidden: false)
        clock.advance(by: 10)
        #expect(items.log == ["show", "hide"])
    }

    // MARK: holdsOpen (the welcome window of YAZ-2801)

    @Test func holdsOpenShowsTheIconsAndStopsTheDelay() {
        let controller = makeHiddenController()
        controller.holdsOpen = true
        #expect(items.isHidden == false)
        #expect(clock.pendingCount == 0)
        clock.advance(by: 3600)
        #expect(items.isHidden == false)

        // Back to false: the delay starts now.
        controller.holdsOpen = false
        clock.advance(by: 9.9)
        #expect(items.isHidden == false)
        clock.advance(by: 0.1)
        #expect(items.isHidden == true)
    }

    @Test func holdsOpenStopsADelayThatRuns() {
        let controller = makeHiddenController()
        controller.toggle()
        controller.holdsOpen = true
        #expect(clock.pendingCount == 0)
    }

    // The welcome window is open and the user clicks the arrow, or presses the hotkey.
    @Test func aClickWorksWhileHoldsOpenIsTrue() {
        let controller = makeHiddenController()
        controller.holdsOpen = true

        controller.toggle()
        #expect(items.isHidden == true)
        controller.toggle()
        #expect(items.isHidden == false)
        // The icons that the user showed stay too: still no delay.
        #expect(clock.pendingCount == 0)

        // The window closes while the icons are hidden. They stay hidden, and nothing waits.
        controller.toggle()
        controller.holdsOpen = false
        #expect(items.isHidden == true)
        #expect(clock.pendingCount == 0)
    }

    @Test func aStartWithHoldsOpenShowsTheIcons() {
        let controller = makeController()
        controller.holdsOpen = true
        controller.start(hidden: true)
        #expect(items.log == ["show"])
        clock.advance(by: 3600)
        #expect(items.log == ["show"])
    }

    // MARK: The dot (YAZ-2800)

    // S21, S22
    @Test func aNewHiddenIconGivesADotUntilTheIconsShow() {
        let controller = makeHiddenController()
        world.hiddenCount = 14
        launchAnApp()
        #expect(items.hasDot == true)
        #expect(items.isHidden == true)

        controller.toggle()
        #expect(items.hasDot == false)
    }

    // S23
    @Test func anAppThatStartsWhileTheIconsShowGivesNoDot() {
        let controller = makeHiddenController()
        controller.hideAfterSeconds = 0
        controller.toggle()
        world.hiddenCount = 14
        launchAnApp()
        #expect(items.hasDot == false)

        // The hide takes the count of 14. The same count later is not a new icon.
        controller.toggle()
        launchAnApp()
        #expect(items.hasDot == false)

        world.hiddenCount = 15
        launchAnApp()
        #expect(items.hasDot == true)
    }

    // S24
    @Test func appsThatStartInTheFirstMinuteGiveNoDot() {
        let controller = makeController()
        // The real clock is the time since the Mac started, not the time since this app started.
        clock.advance(by: 5000)
        controller.start(hidden: true)
        clock.advance(by: 20)
        world.hiddenCount = 20
        launchAnApp()
        #expect(items.hasDot == false)

        clock.advance(by: 100)
        launchAnApp()
        #expect(items.hasDot == false)
        world.hiddenCount = 21
        launchAnApp()
        #expect(items.hasDot == true)
    }

    // A hidden start has no frames, so the hide has no count. The check 2 seconds later takes the count.
    @Test func theCountOfAHiddenStartComesFromTheCheckAfterTheStart() {
        items.arrowFrame = nil
        items.dividerFrame = nil
        let controller = makeController()
        controller.start(hidden: true)
        items.arrowFrame = CGRect(x: 1245, y: 1084, width: 26, height: 33)
        items.dividerFrame = CGRect(x: -3771, y: 1084, width: 5016, height: 33)
        clock.advance(by: 300)
        #expect(world.countCalls == 1)

        // The 13 icons were there from the start. They are not new.
        launchAnApp()
        #expect(items.hasDot == false)
    }

    // The count uses the frame of the divider. With no frame there is no count and no dot.
    @Test func noCountWhenTheDividerHasNoFrame() {
        let controller = makeHiddenController()
        _ = controller
        let callsBefore = world.countCalls
        items.dividerFrame = nil
        world.hiddenCount = 30
        launchAnApp()
        #expect(world.countCalls == callsBefore)
        #expect(items.hasDot == false)
    }
}
