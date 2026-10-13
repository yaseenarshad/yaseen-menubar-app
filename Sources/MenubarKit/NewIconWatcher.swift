import AppKit

/// Asks for one check of the hidden icons a short time after an app starts. It does not poll.
@MainActor final class NewIconWatcher {
    /// An app needs time to make its icon. An icon that comes later is not seen (a known limit).
    static let settleSeconds: TimeInterval = 2

    var onCheck: (() -> Void)?

    private let center: NotificationCenter
    private let schedule: Schedule
    private var observer: NSObjectProtocol?
    private var cancel: Cancel?

    init(center: NotificationCenter, schedule: @escaping Schedule) {
        self.center = center
        self.schedule = schedule
    }

    /// The real launches of the Mac and the real clock.
    convenience init() {
        self.init(center: NSWorkspace.shared.notificationCenter, schedule: RealClock.schedule)
    }

    deinit {
        if let observer = observer { center.removeObserver(observer) }
    }

    /// Starts to listen for app launches. A notification costs nothing while no app starts.
    func start() {
        guard observer == nil else { return }
        observer = center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkSoon() }
        }
    }

    /// Starts the one wait again. Launches that are close together share one check.
    func checkSoon() {
        cancel?()
        cancel = schedule(NewIconWatcher.settleSeconds) { [weak self] in
            self?.cancel = nil
            self?.onCheck?()
        }
    }

    /// The number of icons on the left of the divider, from the window list. It needs no permission.
    static func hiddenIconCount(dividerFrame: CGRect) -> Int {
        let windows = WindowList.frames(at: .statusWindow, onScreenOnly: false)
        // The first screen is the one with the zero of the coordinates.
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let icons = BarLayout.frames(windows, inBandOf: dividerFrame, mainScreenHeight: mainScreenHeight)
        return BarLayout.hiddenCount(iconFrames: icons, dividerMinX: dividerFrame.minX)
    }
}
