// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YaseenMenubar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "YaseenMenubar", targets: ["YaseenMenubar"]),
    ],
    targets: [
        // All the code lives in the library, so the tests can import it.
        .target(name: "MenubarKit"),
        .executableTarget(name: "YaseenMenubar", dependencies: ["MenubarKit"]),
        .testTarget(name: "MenubarKitTests", dependencies: ["MenubarKit"]),
    ],
    // Swift 5 mode: CI uses an older compiler, and AppKit code needs fewer annotations.
    swiftLanguageModes: [.v5]
)
