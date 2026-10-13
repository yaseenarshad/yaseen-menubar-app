import AppKit

/// Joins the state, the status items, the delay, and the check after an app start.
@MainActor public final class BarController {
    /// A right click or a Control-click on the arrow opens this menu.
    public var menu: NSMenu?

    /// The icons hide again after this delay. 0 is "Never".
    public var hideAfterSeconds = 10 {
        didSet { if hideAfterSeconds != oldValue { restartDelay() } }
    }

    /// True: the icons show and no delay runs. Back to false: the delay starts.
    public var holdsOpen = false {
        didSet {
            guard holdsOpen != oldValue else { return }
            if holdsOpen && model.isHidden { show() } else { restartDelay() }
        }
    }

    private let items: StatusItems
    private let autoHide: AutoHide
    private let watcher: NewIconWatcher
    private let hiddenIconCount: @MainActor (CGRect) -> Int
    private let uptime: @MainActor () -> TimeInterval

    private var model = BarModel()
    /// The state that the status items show now.
    private var rendered: BarModel?
    private var isStarted = false
    private var startTime: TimeInterval = 0
    /// True from a repair of the divider until the check that follows it.
    private var repairIsNotChecked = false

    init(
        items: StatusItems,
        autoHide: AutoHide,
        watcher: NewIconWatcher,
        hiddenIconCount: @escaping @MainActor (CGRect) -> Int,
        uptime: @escaping @MainActor () -> TimeInterval
    ) {
        self.items = items
        self.autoHide = autoHide
        self.watcher = watcher
        self.hiddenIconCount = hiddenIconCount
        self.uptime = uptime
    }

    /// Makes the two status items. Call it when the app finished its launch, not before.
    public convenience init() {
        self.init(items: BarItems(defaults: .standard), autoHide: AutoHide(), watcher: NewIconWatcher(),
                  hiddenIconCount: NewIconWatcher.hiddenIconCount, uptime: { ProcessInfo.processInfo.systemUptime })
    }

    /// `hidden` is true at a normal start and false at the first start.
    public func start(hidden: Bool) {
        guard !isStarted else { return }
        isStarted = true
        startTime = uptime()
        items.onClick = { [weak self] isSecondary in self?.clicked(isSecondary: isSecondary) }
        autoHide.onHide = { [weak self] in self?.hide() }
        watcher.onCheck = { [weak self] in self?.check() }
        watcher.start()

        if hidden && !holdsOpen { hide() } else { show() }
        // The frames of new status items are not correct yet. The check takes the first count when they are.
        watcher.checkSoon()
    }

    /// The one entry for a click and for the hotkey.
    public func toggle() {
        guard isStarted else { return }
        if model.isHidden { show() } else { hide() }
    }

    private func clicked(isSecondary: Bool) {
        if !isSecondary {
            toggle()
        } else if let menu {
            items.open(menu)
        }
    }

    private func show() {
        model.show()
        render()
        restartDelay()
    }

    private func hide() {
        autoHide.stop()
        var count = 0
        if let divider = items.dividerFrame {
            if let arrow = items.arrowFrame, !BarLayout.dividerTouchesArrow(dividerFrame: divider, arrowFrame: arrow) {
                // An icon between them would stay shown. A divider on the right of the arrow would push the arrow
                // off the screen.
                items.putDividerLeftOfArrow()
                // The new divider has no frame yet. The check tells if the repair worked.
                repairIsNotChecked = true
                watcher.checkSoon()
            } else {
                // Count before the length changes: the frame of the divider is correct now.
                count = hiddenIconCount(divider)
            }
        }
        model.hide(hiddenCount: count)
        render()
    }

    /// Runs one time, 2 seconds after an app start, after the start of this app, and after a repair.
    private func check() {
        guard let divider = items.dividerFrame else { return }
        let followsRepair = repairIsNotChecked
        repairIsNotChecked = false
        // The order is the rule here, not the touch: an icon between them does not push the arrow off the screen.
        guard let arrow = items.arrowFrame, BarLayout.dividerIsLeftOfArrow(dividerFrame: divider, arrowFrame: arrow) else {
            // The divider is in the menu bar, but the arrow is not on its right. Bring the arrow back.
            // The next hide makes the divider again.
            if model.isHidden {
                show()
                // After a repair that did not work, the delay would repair again and again. Only a click hides now.
                if followsRepair { autoHide.stop() }
            }
            return
        }
        let count = hiddenIconCount(divider)
        if followsRepair && model.isHidden {
            // The hide with the repair had no count. The repair can move an icon of the user to the hidden side.
            // That icon is not a new icon, so this count gives no dot.
            model.hide(hiddenCount: count)
        } else {
            model.appStarted(hiddenCount: count, secondsSinceStart: uptime() - startTime)
        }
        render()
    }

    private func render() {
        guard model != rendered else { return }
        items.render(model)
        rendered = model
    }

    /// The delay runs only while the icons show.
    private func restartDelay() {
        let runs = isStarted && !model.isHidden && !holdsOpen
        autoHide.start(seconds: runs ? hideAfterSeconds : 0)
    }
}
