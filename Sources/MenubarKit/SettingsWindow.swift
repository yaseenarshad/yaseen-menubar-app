import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The three rows of the settings window: open at login, the delay, and the hotkey.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Open at login", isOn: Binding(
                    get: { model.openAtLogin },
                    set: { model.setOpenAtLogin($0) }
                ))
                .toggleStyle(.switch)
                .disabled(!model.loginItemIsAvailable)

                if let note = model.loginItemNote {
                    Text(note).font(.callout).foregroundStyle(.secondary)
                }
                if let problem = model.loginItemProblem {
                    Text(problem).font(.callout).foregroundStyle(.red)
                }
            }

            Picker("Hide again after", selection: Binding(
                get: { model.hideAfterSeconds },
                set: { model.setHideAfterSeconds($0) }
            )) {
                ForEach(SettingsModel.hideAfterChoices, id: \.self) { seconds in
                    Text(SettingsModel.hideAfterText(seconds)).tag(seconds)
                }
            }

            LabeledContent("Hotkey") {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        // The hotkey field: a click starts the recording, a second click stops it.
                        // The window controller gives the keys to the model while the field records.
                        Button(action: toggleRecording) {
                            Text(model.hotKeyText).frame(minWidth: 120)
                        }
                        Button("Clear") { model.clearHotKey() }
                            .disabled(model.hotKey == nil)
                    }
                    if let problem = model.hotKeyProblem {
                        Text(problem).font(.callout).foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func toggleRecording() {
        if model.isRecording {
            model.cancelRecording()
        } else {
            model.startRecording()
        }
    }
}

/// The one settings window of the app.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private let window: NSWindow
    private let present: @MainActor (NSWindow) -> Void
    /// Not `nil` only while the window is open.
    private(set) var keyMonitor: Any?

    /// A test gives its own `present`, so no window comes on the screen.
    init(model: SettingsModel, present: @escaping @MainActor (NSWindow) -> Void = { $0.showInFront() }) {
        self.model = model
        self.present = present
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 10),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        super.init()

        window.title = "Yaseen Menubar settings"
        // The controller keeps the window, so "Settings…" shows the same window again.
        window.isReleasedWhenClosed = false
        window.delegate = self

        let host = NSHostingController(rootView: SettingsView(model: model))
        // The window follows the height of the form: a red line adds a row.
        host.sizingOptions = [.preferredContentSize]
        window.contentViewController = host
        window.center()
    }

    deinit {
        if let keyMonitor = keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    /// Shows the window in front of other apps. A second call shows the same window.
    func show() {
        model.refreshOpenAtLogin()
        addKeyMonitor()
        present(window)
    }

    /// A monitor sees a key before the window does. Thus the field also gets a combination with Command,
    /// which the window would handle as a key equivalent.
    private func addKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only plain values cross into the main actor: `NSEvent` is not `Sendable`.
            guard let combo = HotKeyCombo(keyDown: event) else { return event }
            let windowNumber = event.windowNumber
            let used = MainActor.assumeIsolated { self?.keyDown(combo, windowNumber: windowNumber) ?? false }
            // `nil` tells AppKit that the key is used.
            return used ? nil : event
        }
    }

    /// Returns `true` when the key is used.
    private func keyDown(_ combo: HotKeyCombo, windowNumber: Int) -> Bool {
        guard windowNumber == window.windowNumber else { return false }
        if model.keyDown(combo) { return true }
        // The app has no main menu, so nothing else gives Command-W to the window.
        if combo == HotKeyCombo(keyCode: UInt32(kVK_ANSI_W), modifiers: .command) {
            window.performClose(nil)
            return true
        }
        return false
    }

    // MARK: NSWindowDelegate

    // A recording must not stay open with the global hotkey off.
    func windowDidResignKey(_ notification: Notification) {
        model.cancelRecording()
    }

    func windowWillClose(_ notification: Notification) {
        model.cancelRecording()
        // The app keeps this controller. A closed window must not leave a monitor behind.
        if let keyMonitor = keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // The user can come back from System Settings, Login Items.
        model.refreshOpenAtLogin()
    }
}
