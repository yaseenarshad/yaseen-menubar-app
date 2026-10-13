import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing
@testable import MenubarKit

/// The settings window (YAZ-2801). `present` does nothing here, so no window comes on the screen.
@MainActor
@Suite struct SettingsWindowTests {
    // S31 and S32.
    @Test func settingsASecondTimeShowsTheSameWindow() {
        let loginItem = FakeLoginItem()
        let model = SettingsModel(store: SettingsStore(defaults: MemoryDefaults()), hotKeys: FakeHotKeys(), loginItem: loginItem)
        var presented: [NSWindow] = []
        let controller = SettingsWindowController(model: model) { presented.append($0) }

        // The user turned the login item on in System Settings. The window shows the real state when it opens.
        loginItem.isEnabled = true
        controller.show()
        controller.show()
        #expect(presented.count == 2)
        #expect(presented[0] === presented[1])
        #expect(model.openAtLogin == true)
        #expect(presented[0].title == "Yaseen Menubar settings")
    }

    @Test func aRecordingStopsWhenTheWindowCloses() {
        let hotKeys = FakeHotKeys()
        let model = SettingsModel(store: SettingsStore(defaults: MemoryDefaults()), hotKeys: hotKeys, loginItem: FakeLoginItem())
        var window: NSWindow?
        let controller = SettingsWindowController(model: model) { window = $0 }
        controller.show()

        model.startRecording()
        window?.close()
        #expect(!model.isRecording)
    }

    /// The form lays out with no window. The lines for a problem make it higher.
    @Test func theFormHasASizeAndGrowsWithTheProblemLines() {
        let hotKeys = FakeHotKeys()
        let loginItem = FakeLoginItem()
        let commandB = HotKeyCombo(keyCode: UInt32(kVK_ANSI_B), modifiers: .command)
        let store = SettingsStore(defaults: MemoryDefaults())
        store.hotKey = commandB
        let model = SettingsModel(store: store, hotKeys: hotKeys, loginItem: loginItem)
        @MainActor func size() -> CGSize {
            NSHostingView(rootView: SettingsView(model: model)).fittingSize
        }
        let plain = size()
        #expect(plain.width == 460)
        #expect(plain.height > 100 && plain.height < 400)

        // macOS refuses the stored hotkey at the start.
        hotKeys.refused = [commandB]
        model.registerHotKey()
        let withHotKeyLine = size().height
        #expect(withHotKeyLine > plain.height)

        loginItem.refuses = true
        model.setOpenAtLogin(true)
        #expect(size().height > withHotKeyLine)
    }
}
