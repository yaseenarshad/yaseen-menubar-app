import Foundation
import MenubarKit
import Testing

/// The code and `Support/Info.plist` must tell the same facts about the app.
@Suite struct AppInfoTests {
    /// `Support/Info.plist`, found from the path of this file. The tests run from the repository.
    static func infoPlist() throws -> [String: Any] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // MenubarKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // the repository root
        let data = try Data(contentsOf: root.appendingPathComponent("Support/Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test func bundleIdentifierIsTheOneInTheInfoPlist() throws {
        let plist = try AppInfoTests.infoPlist()
        #expect(plist["CFBundleIdentifier"] as? String == AppController.bundleIdentifier)
    }

    @Test func appHasNoDockIconAndAsksForNoPermission() throws {
        let plist = try AppInfoTests.infoPlist()
        #expect(plist["LSUIElement"] as? Bool == true)
        // A key like `NSCameraUsageDescription` makes macOS ask for a permission. The app needs none.
        #expect(plist.keys.filter { $0.hasSuffix("UsageDescription") }.isEmpty)
    }
}
