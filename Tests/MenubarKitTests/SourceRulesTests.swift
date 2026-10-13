import Foundation
import Testing

/// Rules for all the code of the app: zero permissions, and one place that makes a timer (YAZ-2788).
@Suite struct SourceRulesTests {
    /// The text of each Swift file in `Sources`, found from the path of this file.
    static func sources() throws -> [(name: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // MenubarKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // the repository root
        let files = FileManager.default.enumerator(at: root.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)
        return try (files?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "swift" }
            .map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    @Test func theCodeUsesNoCallThatNeedsAPermission() throws {
        // Each of these needs Screen Recording, Accessibility, or Input Monitoring.
        let forbidden = ["kCGWindowName", "CGWindowListCreateImage", "SCShareableContent", "AXUIElement",
                         "AXIsProcessTrusted", "CGEvent.tapCreate", "addGlobalMonitorForEvents"]
        let sources = try SourceRulesTests.sources()
        #expect(!sources.isEmpty)
        for source in sources {
            for call in forbidden {
                #expect(!source.text.contains(call), "\(source.name) uses \(call)")
            }
        }
    }

    // "No timer while the icons are hidden" has a proof only if each wait goes through `RealClock.schedule`:
    // the tests give a fake clock in its place and count the waits.
    @Test func onlyTheClockMakesATimerAndItDoesNotRepeat() throws {
        let waits = ["Timer.", "Timer(", "DispatchSource", "asyncAfter", "Task.sleep", "afterDelay", "CADisplayLink"]
        for source in try SourceRulesTests.sources() {
            if source.name == "Schedule.swift" {
                #expect(source.text.contains("repeats: false") && !source.text.contains("repeats: true"))
            } else {
                for call in waits {
                    #expect(!source.text.contains(call), "\(source.name) uses \(call)")
                }
            }
            // The one monitor is for the keys of the settings window. It is local, and the window removes it when it closes.
            if source.name != "SettingsWindow.swift" {
                #expect(!source.text.contains("MonitorForEvents"), "\(source.name) adds an event monitor")
            }
        }
    }
}
