import AppKit
import SwiftUI
import Testing
@testable import MenubarKit

/// The welcome window (YAZ-2801). `present` does nothing here, so no window comes on the screen.
@MainActor
@Suite struct WelcomeWindowTests {
    // S39 and S40: the app holds the icons open from `onOpen` to `onClose`.
    @Test func openAndCloseComeInPairs() {
        var presented: [NSWindow] = []
        var events: [String] = []
        let controller = WelcomeWindowController(bartenderIsRunning: { false }) { presented.append($0) }
        controller.onOpen = { events.append("open") }
        controller.onClose = { events.append("close") }

        controller.show()
        #expect(events == ["open"])
        // "How to hide an icon" while the window is open: the same window, and no second `onOpen`.
        controller.show()
        #expect(events == ["open"])
        #expect(presented.count == 2)
        #expect(presented[0] === presented[1])

        presented[0].close()
        #expect(events == ["open", "close"])

        // The window opens again after it closed.
        controller.show()
        #expect(events == ["open", "close", "open"])
        #expect(presented[2] === presented[0])
    }

    @Test func doneClosesTheWindow() {
        var events: [String] = []
        let controller = WelcomeWindowController(bartenderIsRunning: { false }) { _ in }
        controller.onClose = { events.append("close") }

        controller.show()
        controller.content.onDone()
        #expect(events == ["close"])
        // A second close of a closed window tells nothing.
        controller.content.onDone()
        #expect(events == ["close"])
    }

    // S35: the line shows the state of Bartender at the moment the window opens.
    @Test func theBartenderLineFollowsTheCheckAtEachShow() {
        var isRunning = true
        let controller = WelcomeWindowController(bartenderIsRunning: { isRunning }) { _ in }
        controller.show()
        #expect(controller.content.bartenderIsRunning == true)

        isRunning = false
        controller.show()
        #expect(controller.content.bartenderIsRunning == false)
    }

    /// The view lays out with no window. The Bartender line makes it higher.
    @Test func theViewHasASizeAndGrowsWithTheBartenderLine() {
        @MainActor func size(_ bartenderIsRunning: Bool) -> CGSize {
            NSHostingView(rootView: WelcomeView(bartenderIsRunning: bartenderIsRunning, onDone: {})).fittingSize
        }
        let plain = size(false)
        #expect(plain.width == 420)
        #expect(plain.height > 150 && plain.height < 400)
        #expect(size(true).height > plain.height)
    }

    @Test func theTextOfTheWindow() {
        #expect(WelcomeView.titleText == "How to hide an icon")
        #expect(WelcomeView.bodyLines.joined(separator: " ") == "Hold Command and drag an icon. Left of the line: hidden. Right of the arrow: always shows. Click the arrow to hide or show.")
        #expect(WelcomeView.bartenderText == "Bartender is running. Quit Bartender first.")
    }
}
