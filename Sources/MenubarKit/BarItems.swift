import AppKit

/// What the controller needs from the two status items. The tests give a fake here.
@MainActor protocol StatusItems: AnyObject {
    /// A click on the arrow. The value is true for a right click or a Control-click.
    var onClick: ((_ isSecondary: Bool) -> Void)? { get set }
    /// The frame of the arrow on the screen, or `nil` while the frame is not in a menu bar.
    var arrowFrame: CGRect? { get }
    /// The frame of the divider on the screen, or `nil` while the frame is not in a menu bar.
    var dividerFrame: CGRect? { get }
    /// Shows the state: the length of the divider, the direction of the arrow, and the dot.
    func render(_ model: BarModel)
    /// Makes the divider again, directly on the left of the arrow.
    func putDividerLeftOfArrow()
    /// Opens the menu below the arrow.
    func open(_ menu: NSMenu)
}

/// Owns the two status items: the arrow and the divider.
@MainActor final class BarItems: NSObject, StatusItems {
    static let arrowName = "YMArrow"
    static let dividerName = "YMDivider"
    /// The saved position of the arrow at the first start. It puts the arrow on the right of the notch.
    static let firstArrowPosition: Double = 420
    /// A divider with a position this much larger lands directly on the left of the arrow.
    static let dividerOffset: Double = 10

    var onClick: ((Bool) -> Void)?

    private(set) var arrow: NSStatusItem
    private(set) var divider: NSStatusItem
    private let defaults: UserDefaults

    // On macOS 26 each write to a status item costs memory in Control Center. Thus the last written values stay here.
    private var writtenLength: CGFloat?
    private var writtenArrow: ArrowLook?

    private struct ArrowLook: Equatable {
        let pointsLeft: Bool
        let hasDot: Bool
    }

    /// AppKit reads the saved positions from the standard defaults. Give a different object only in a test.
    init(defaults: UserDefaults) {
        self.defaults = defaults
        // The positions must be there before AppKit makes the status items.
        BarItems.prepareSavedPositions(in: defaults)
        arrow = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        arrow.autosaveName = BarItems.arrowName
        divider = BarItems.makeDivider()
        super.init()

        arrow.button?.target = self
        arrow.button?.action = #selector(arrowClicked)
        arrow.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: The state

    func render(_ model: BarModel) {
        if model.dividerLength != writtenLength {
            divider.length = model.dividerLength
            // A stretched divider shows no line. Its middle can be on the screen of a wide display.
            let line = model.isHidden ? nil : BarItems.lineImage
            if divider.button?.image !== line { divider.button?.image = line }
            writtenLength = model.dividerLength
        }
        let look = ArrowLook(pointsLeft: model.isHidden, hasDot: model.hasNewIcon)
        if look != writtenArrow {
            arrow.button?.image = BarItems.arrowImage(pointsLeft: look.pointsLeft, hasDot: look.hasDot)
            writtenArrow = look
        }
    }

    // MARK: The frames

    var arrowFrame: CGRect? { frameInMenuBar(of: arrow) }
    var dividerFrame: CGRect? { frameInMenuBar(of: divider) }

    /// The window list does not have the windows of this app: Control Center owns the real ones.
    /// The window of the button has the true frame, about 150 ms after a change.
    private func frameInMenuBar(of item: NSStatusItem) -> CGRect? {
        guard let frame = item.button?.window?.frame,
              BarLayout.isInMenuBar(frame, screenFrames: NSScreen.screens.map(\.frame)) else { return nil }
        return frame
    }

    // MARK: The divider

    private static func makeDivider() -> NSStatusItem {
        // The start length is 1. With 0, macOS makes no real window. `render` writes the real length.
        let divider = NSStatusBar.system.statusItem(withLength: 1)
        divider.autosaveName = dividerName
        return divider
    }

    func putDividerLeftOfArrow() {
        NSStatusBar.system.removeStatusItem(divider)
        // AppKit can delete the saved position of a status item that goes away. Thus write the position after that.
        let savedArrow = defaults.object(forKey: BarItems.positionKey(BarItems.arrowName)) as? Double
        let dividerKey = BarItems.positionKey(BarItems.dividerName)
        if let position = BarItems.repairedDividerPosition(savedArrow: savedArrow) {
            defaults.set(position, forKey: dividerKey)
        } else {
            defaults.removeObject(forKey: dividerKey)
        }
        divider = BarItems.makeDivider()
        writtenLength = nil
    }

    // MARK: The saved positions

    private static func positionKey(_ name: String) -> String { "NSStatusItem Preferred Position \(name)" }

    /// The positions to write before the status items exist. `nil` means: write nothing for that one.
    /// A larger position is further left. The divider must be on the left of the arrow.
    static func positionsToWrite(savedArrow: Double?, savedDivider: Double?) -> (arrow: Double?, divider: Double?) {
        let arrow = savedArrow ?? firstArrowPosition
        let dividerIsOnTheLeft = savedDivider.map { $0 > arrow } ?? false
        return (savedArrow == nil ? arrow : nil, dividerIsOnTheLeft ? nil : arrow + dividerOffset)
    }

    /// The position for a divider that the app makes again while the arrow exists. `nil` means: save no position.
    static func repairedDividerPosition(savedArrow: Double?) -> Double? {
        // With no saved position, macOS puts a new icon at the far left. That is on the left of the arrow.
        savedArrow.map { $0 + dividerOffset }
    }

    private static func prepareSavedPositions(in defaults: UserDefaults) {
        let arrowKey = positionKey(arrowName), dividerKey = positionKey(dividerName)
        let positions = positionsToWrite(savedArrow: defaults.object(forKey: arrowKey) as? Double,
                                         savedDivider: defaults.object(forKey: dividerKey) as? Double)
        if let arrow = positions.arrow { defaults.set(arrow, forKey: arrowKey) }
        if let divider = positions.divider { defaults.set(divider, forKey: dividerKey) }
    }

    // MARK: The clicks

    @objc private func arrowClicked() {
        guard let event = NSApp.currentEvent else { return }
        onClick?(BarItems.isSecondaryClick(type: event.type, modifiers: event.modifierFlags))
    }

    static func isSecondaryClick(type: NSEvent.EventType, modifiers: NSEvent.ModifierFlags) -> Bool {
        type == .rightMouseUp || modifiers.contains(.control)
    }

    func open(_ menu: NSMenu) {
        // A status item with a menu opens it on each click. Thus the arrow has the menu only for this one click.
        arrow.menu = menu
        arrow.button?.performClick(nil)
        arrow.menu = nil
    }

    // MARK: The images

    static func arrowImage(pointsLeft: Bool, hasDot: Bool) -> NSImage? {
        let name = pointsLeft ? "chevron.left" : "chevron.right"
        let text = !pointsLeft ? "Hide the icons" : hasDot ? "Show the hidden icons. A new icon is hidden." : "Show the hidden icons"
        guard let chevron = NSImage(systemSymbolName: name, accessibilityDescription: text) else { return nil }
        guard hasDot else { return chevron }

        // The same arrow with a small dot at the top right.
        let dot: CGFloat = 5
        let size = NSSize(width: chevron.size.width + dot, height: chevron.size.height)
        let image = NSImage(size: size, flipped: false) { _ in
            chevron.draw(in: NSRect(origin: .zero, size: chevron.size))
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: size.width - dot, y: size.height - dot, width: dot, height: dot)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = text
        return image
    }

    /// The thin line of the divider.
    private static let lineImage: NSImage = {
        let image = NSImage(size: NSSize(width: 1, height: 12), flipped: false) { rect in
            NSColor.black.withAlphaComponent(0.4).setFill()
            rect.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Divider. The icons on its left hide."
        return image
    }()
}
