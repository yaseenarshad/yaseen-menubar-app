import AppKit

/// The menu that a right-click on the arrow opens.
@MainActor
final class ArrowMenu: NSObject {
    var onSettings: () -> Void = {}
    var onHowTo: () -> Void = {}
    var onQuit: () -> Void = {}

    let menu = NSMenu()

    override init() {
        super.init()
        menu.addItem(row("Settings…", #selector(settings), key: ","))
        menu.addItem(row("How to hide an icon", #selector(howTo)))
        menu.addItem(.separator())
        menu.addItem(row("Quit Yaseen Menubar", #selector(quit), key: "q"))
    }

    private func row(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func settings() { onSettings() }
    @objc private func howTo() { onHowTo() }
    @objc private func quit() { onQuit() }
}
