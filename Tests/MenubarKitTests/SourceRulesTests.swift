import Foundation
import Testing

/// Rules for all the code of the app: zero permissions, and no timer that repeats (YAZ-2788).
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

    @Test func noTimerRepeats() throws {
        for source in try SourceRulesTests.sources() {
            #expect(!source.text.contains("repeats: true"), "\(source.name) has a timer that repeats")
        }
    }
}
