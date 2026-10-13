import AppKit
import Testing
@testable import MenubarKit

/// The right-click menu of the arrow (decision 9). The menu is built but never opened.
@MainActor
@Suite struct ArrowMenuTests {
    @Test func theMenuHasThreeRowsAndOneSeparator() {
        let items = ArrowMenu().menu.items
        #expect(items.map(\.title) == ["Settings…", "How to hide an icon", "", "Quit Yaseen Menubar"])
        #expect(items.map(\.isSeparatorItem) == [false, false, true, false])
    }

    @Test func eachRowRunsItsClosure() {
        let arrowMenu = ArrowMenu()
        var calls: [String] = []
        arrowMenu.onSettings = { calls.append("settings") }
        arrowMenu.onHowTo = { calls.append("how to") }
        arrowMenu.onQuit = { calls.append("quit") }

        // The same call that AppKit makes for a click on the row.
        for item in arrowMenu.menu.items where !item.isSeparatorItem {
            _ = item.target?.perform(item.action, with: item)
        }
        #expect(calls == ["settings", "how to", "quit"])
    }
}
