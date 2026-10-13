import CoreGraphics
import Testing
@testable import MenubarKit

/// Where the menu bar is on a screen, and which frames are in it. The numbers come from the built-in display.
@Suite struct MenuBarBandTests {
    let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let visible = CGRect(x: 0, y: 0, width: 1728, height: 1083)

    // S6: the band is the part of the screen above the visible frame.
    @Test func theBandIsTheTopOfTheScreen() {
        let band = BarLayout.menuBarBand(screenFrame: screen, visibleFrame: visible, statusBarThickness: 22)
        #expect(band.contains(CGPoint(x: 800, y: 1100)))
        #expect(band.contains(CGPoint(x: 0, y: 1083)))
        // The pointer at the top edge of the screen is in the band.
        #expect(band.contains(CGPoint(x: 1727, y: 1117)))
        #expect(!band.contains(CGPoint(x: 800, y: 1082)))
        #expect(!band.contains(CGPoint(x: 1800, y: 1100)))
    }

    // The menu bar hides itself: the visible frame is the full screen. The band is then the thickness of the status bar.
    @Test func aHiddenMenuBarStillHasABand() {
        let band = BarLayout.menuBarBand(screenFrame: screen, visibleFrame: screen, statusBarThickness: 22)
        #expect(band.contains(CGPoint(x: 800, y: 1116)))
        #expect(!band.contains(CGPoint(x: 800, y: 1090)))
    }

    // The frame of a status item is correct only when it is in the menu bar of a screen (probes on macOS 26.6.2).
    @Test func aFrameIsInAMenuBarWhenItsTopIsTheTopOfAScreen() {
        let screens = [screen, CGRect(x: 1728, y: 0, width: 2560, height: 1440)]
        #expect(BarLayout.isInMenuBar(CGRect(x: 1245, y: 1084, width: 26, height: 33), screenFrames: screens))
        // A stretched divider: its right end is on the screen.
        #expect(BarLayout.isInMenuBar(CGRect(x: -3771, y: 1084, width: 5016, height: 33), screenFrames: screens))
        #expect(BarLayout.isInMenuBar(CGRect(x: 3000, y: 1418, width: 26, height: 22), screenFrames: screens))

        // The frames of a new status item, before macOS places it.
        #expect(!BarLayout.isInMenuBar(CGRect(x: 0, y: 0, width: 26, height: 0), screenFrames: screens))
        #expect(!BarLayout.isInMenuBar(CGRect(x: 0, y: -33, width: 26, height: 33), screenFrames: screens))
        #expect(!BarLayout.isInMenuBar(CGRect(x: 0, y: -28, width: 26, height: 33), screenFrames: screens))
        // An arrow that a wrong divider pushed off the screen, and a thin divider with an old x.
        #expect(!BarLayout.isInMenuBar(CGRect(x: -3771, y: 1084, width: 26, height: 33), screenFrames: screens))
        #expect(!BarLayout.isInMenuBar(CGRect(x: -3771, y: 1084, width: 24, height: 33), screenFrames: screens))
    }

    // The window list has its zero at the top of the main screen, and y grows down.
    @Test func statusWindowsInTheBandOfTheDivider() {
        let divider = CGRect(x: 1221, y: 1084, width: 24, height: 33)
        let windows = [
            CGRect(x: 1190, y: 0, width: 31, height: 33),
            CGRect(x: 1271, y: 0, width: 38, height: 33),
            // A status window of a different screen, and a window that is not in a menu bar.
            CGRect(x: 2000, y: -323, width: 38, height: 22),
            CGRect(x: 0, y: 500, width: 38, height: 33),
        ]
        #expect(BarLayout.frames(windows, inBandOf: divider, mainScreenHeight: 1117) == Array(windows.prefix(2)))
    }
}
