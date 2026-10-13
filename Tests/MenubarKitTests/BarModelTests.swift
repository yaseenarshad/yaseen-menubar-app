import CoreGraphics
import Testing
@testable import MenubarKit

/// The state of the menu bar, with no real menu bar (YAZ-2799, YAZ-2800).
@Suite struct BarModelTests {
    @Test func aNewModelShowsTheIcons() {
        let model = BarModel()
        #expect(!model.isHidden)
        #expect(!model.hasNewIcon)
        #expect(model.dividerLength == DividerLength.thin)
    }

    // S1, S2: the hide method is the length of the divider.
    @Test func hideStretchesTheDividerAndShowMakesItThinAgain() {
        var model = BarModel()
        model.hide(hiddenCount: 13)
        #expect(model.isHidden)
        #expect(model.dividerLength == 10_000)

        model.show()
        #expect(!model.isHidden)
        #expect(model.dividerLength == 8)
    }

    // S21, S22
    @Test func aNewIconOnTheHiddenSideGivesADotUntilTheIconsShow() {
        var model = BarModel()
        model.hide(hiddenCount: 13)
        model.appStarted(hiddenCount: 14, secondsSinceStart: 300)
        #expect(model.hasNewIcon)

        model.show()
        #expect(!model.hasNewIcon)
    }

    // S23
    @Test func anAppThatStartsWhileTheIconsShowGivesNoDot() {
        var model = BarModel()
        model.appStarted(hiddenCount: 14, secondsSinceStart: 300)
        #expect(!model.hasNewIcon)

        // The count at the hide is now the highest count. The same count later gives no dot.
        model.hide(hiddenCount: 14)
        model.appStarted(hiddenCount: 14, secondsSinceStart: 400)
        #expect(!model.hasNewIcon)
    }

    // S24: at login many apps start. A dot then is noise.
    @Test func appsThatStartInTheFirstMinuteGiveNoDot() {
        var model = BarModel()
        model.hide(hiddenCount: 2)
        model.appStarted(hiddenCount: 9, secondsSinceStart: 20)
        #expect(!model.hasNewIcon)

        // The quiet count still raised the highest count.
        model.appStarted(hiddenCount: 9, secondsSinceStart: 120)
        #expect(!model.hasNewIcon)

        model.appStarted(hiddenCount: 10, secondsSinceStart: 121)
        #expect(model.hasNewIcon)
    }

    // S26: the app cannot name icons. Only a count above the highest count is a new icon.
    @Test func aHiddenAppThatQuitsAndStartsAgainGivesNoDot() {
        var model = BarModel()
        model.hide(hiddenCount: 13)
        model.show()
        model.hide(hiddenCount: 12)
        model.appStarted(hiddenCount: 13, secondsSinceStart: 300)
        #expect(!model.hasNewIcon)
    }
}

/// The geometry rules. The frames come from the probes on macOS 26.6.2 (Finding 2 and Finding 4 on YAZ-2788).
@Suite struct BarLayoutTests {
    private func icon(_ x: CGFloat, width: CGFloat = 38) -> CGRect {
        CGRect(x: x, y: 0, width: width, height: 33)
    }

    // S17: a divider on the right of the arrow would push the arrow off the screen.
    @Test func theDividerMustBeOnTheLeftOfTheArrow() {
        let arrow = icon(1389)
        #expect(BarLayout.dividerIsLeftOfArrow(dividerFrame: icon(1365, width: 24), arrowFrame: arrow))
        #expect(BarLayout.dividerIsLeftOfArrow(dividerFrame: icon(-3627, width: 5016), arrowFrame: arrow))
        #expect(!BarLayout.dividerIsLeftOfArrow(dividerFrame: icon(1427, width: 24), arrowFrame: arrow))
    }

    @Test func hiddenCountCountsTheIconsOnTheLeftOfTheDivider() {
        // The divider is stretched: its frame starts at x = -3627.
        let stretched = [icon(-4325), icon(-4287, width: 36), icon(-3665), icon(1427, width: 42), icon(1654, width: 76)]
        #expect(BarLayout.hiddenCount(iconFrames: stretched, dividerMinX: -3627) == 3)

        // The divider is thin at x = 1365. The count is the same group.
        let thin = [icon(987, width: 40), icon(1027), icon(1327), icon(1427, width: 42), icon(1654, width: 76)]
        #expect(BarLayout.hiddenCount(iconFrames: thin, dividerMinX: 1365) == 3)

        // The frame of the divider itself is not an icon of the hidden group.
        #expect(BarLayout.hiddenCount(iconFrames: [icon(-3627, width: 5016)], dividerMinX: -3627) == 0)
        #expect(BarLayout.hiddenCount(iconFrames: [], dividerMinX: 1365) == 0)
    }
}
