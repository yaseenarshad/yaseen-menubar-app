import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing
@testable import MenubarKit

/// Writes pictures of the content of the two windows, for a review by eye.
///
/// It runs only with `MENUBAR_UI_PNG_DIR=<folder>`. Nothing comes on the screen: each view draws into a bitmap.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MENUBAR_UI_PNG_DIR"] != nil))
struct WindowPictureTests {
    private func write<Content: View>(_ view: Content, to name: String, dark: Bool = false) throws {
        let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["MENUBAR_UI_PNG_DIR"]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        // The switch and the buttons draw only in a window. This window is never ordered on the screen.
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: true)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        // The view has no background of its own. Draw the one of a window first, or a dark picture has no contrast.
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            context.cgContext.setFillColor(NSColor.windowBackgroundColor.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: folder.appendingPathComponent(name))
    }

    @Test func theSettingsWindow() throws {
        let model = SettingsModel(store: SettingsStore(defaults: MemoryDefaults()), hotKeys: FakeHotKeys(), loginItem: FakeLoginItem())
        try write(SettingsView(model: model), to: "settings.png")
        try write(SettingsView(model: model), to: "settings-dark.png", dark: true)

        // Each line that the window can show: a hotkey, a refused hotkey, and the note of `swift run`.
        let hotKeys = FakeHotKeys()
        hotKeys.refused = [HotKeyCombo(keyCode: UInt32(kVK_F6), modifiers: .command)]
        let loginItem = FakeLoginItem()
        loginItem.isAvailable = false
        let full = SettingsModel(store: SettingsStore(defaults: MemoryDefaults()), hotKeys: hotKeys, loginItem: loginItem)
        full.startRecording()
        _ = full.keyDown(HotKeyCombo(keyCode: UInt32(kVK_ANSI_B), modifiers: [.control, .option]))
        full.startRecording()
        _ = full.keyDown(HotKeyCombo(keyCode: UInt32(kVK_F6), modifiers: .command))
        try write(SettingsView(model: full), to: "settings-all-lines.png")
    }

    @Test func theWelcomeWindow() throws {
        try write(WelcomeView(bartenderIsRunning: false, onDone: {}), to: "welcome.png")
        try write(WelcomeView(bartenderIsRunning: true, onDone: {}), to: "welcome-bartender.png")
        try write(WelcomeView(bartenderIsRunning: true, onDone: {}), to: "welcome-dark.png", dark: true)
    }
}
