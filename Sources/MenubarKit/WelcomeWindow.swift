import AppKit
import SwiftUI

/// The content of the welcome window: how the user selects the hidden icons.
struct WelcomeView: View {
    static let titleText = "How to hide an icon"
    /// One sentence on each line.
    static let bodyLines = [
        "Hold Command and drag an icon.",
        "Left of the arrow: hidden.",
        "Right of the arrow: always shows.",
        "Click the arrow to hide or show.",
    ]
    static let bartenderText = "Bartender is running. Quit Bartender first."

    let bartenderIsRunning: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(WelcomeView.titleText).font(.title2).bold()
            // VoiceOver would read the name of each symbol. The lines of text below tell the same as the drawing.
            MenuBarDrawing().frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(WelcomeView.bodyLines, id: \.self) { Text($0) }
            }
            if bartenderIsRunning {
                Label {
                    Text(WelcomeView.bartenderText)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            HStack {
                Spacer()
                Button("Done", action: onDone).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A made-up menu bar: the hidden icons, the arrow, and the icons that always show. The arrow is the line between them.
private struct MenuBarDrawing: View {
    /// The arrow as it is while the icons show. The icons show while the welcome window is open.
    private static let arrowSymbol = "chevron.right"
    private static let barHeight: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            part("Hidden") { icons(["cloud.fill", "bell.fill", "printer.fill"]).foregroundStyle(.tertiary) }
            part("Arrow") { Image(systemName: MenuBarDrawing.arrowSymbol).fontWeight(.semibold) }
            part("Always shows") { icons(["wifi", "speaker.wave.2.fill", "magnifyingglass"]) }
        }
        .padding(.horizontal, 16)
        // The bar is behind the top row only. The names are below it.
        .background(alignment: .top) {
            RoundedRectangle(cornerRadius: 7).fill(.quaternary).frame(height: MenuBarDrawing.barHeight)
        }
    }

    /// One part of the bar, with its name below.
    private func part<Content: View>(_ name: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            content().frame(height: MenuBarDrawing.barHeight)
            Text(name).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func icons(_ symbols: [String]) -> some View {
        HStack(spacing: 14) {
            ForEach(symbols, id: \.self) { Image(systemName: $0) }
        }
    }
}

/// The one welcome window of the app. It opens at the first start and from "How to hide an icon".
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    nonisolated static let bartenderBundleIdentifier = "com.surteesstudios.Bartender"

    /// Runs when the window goes from closed to open. The app holds the icons open from here.
    var onOpen: () -> Void = {}
    /// Runs one time when the window closes.
    var onClose: () -> Void = {}

    private let bartenderIsRunning: () -> Bool
    private let present: @MainActor (NSWindow) -> Void
    private let window: NSWindow
    private let host: NSHostingController<WelcomeView>
    private var isOpen = false

    /// The view that the window shows now.
    var content: WelcomeView { host.rootView }

    /// A test gives its own closures, so it reads no real app list and no window comes on the screen.
    init(
        bartenderIsRunning: @escaping () -> Bool = WelcomeWindowController.bartenderRuns,
        present: @escaping @MainActor (NSWindow) -> Void = { $0.showInFront() }
    ) {
        self.bartenderIsRunning = bartenderIsRunning
        self.present = present
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 10),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        host = NSHostingController(rootView: WelcomeView(bartenderIsRunning: false, onDone: {}))
        super.init()

        window.title = "Yaseen Menubar"
        // The controller keeps the window, so a second `show()` shows the same window.
        window.isReleasedWhenClosed = false
        window.delegate = self
        // The window follows the height of the view: the Bartender line adds a row.
        host.sizingOptions = [.preferredContentSize]
        window.contentViewController = host
        window.center()
    }

    /// True when Bartender runs. The app only tells this. It never quits Bartender.
    nonisolated static func bartenderRuns() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bartenderBundleIdentifier).isEmpty
    }

    /// Shows the window in front of other apps. A second call shows the same window.
    func show() {
        host.rootView = WelcomeView(bartenderIsRunning: bartenderIsRunning()) { [weak self] in
            self?.window.close()
        }
        if !isOpen {
            isOpen = true
            onOpen()
        }
        present(window)
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard isOpen else { return }
        isOpen = false
        onClose()
    }
}
