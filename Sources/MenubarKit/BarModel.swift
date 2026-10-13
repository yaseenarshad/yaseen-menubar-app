import CoreGraphics

/// The two lengths of the divider. The length is the hide method.
public enum DividerLength {
    /// macOS pushes each icon on the left of a divider this long off the screen.
    public static let stretched: CGFloat = 10_000
    /// A thin divider. macOS gives it a real width of 24 points.
    public static let thin: CGFloat = 8
}

/// The state of the menu bar, with no real menu bar.
public struct BarModel: Equatable {
    public private(set) var isHidden = false
    /// True when a new icon landed on the hidden side. The arrow then shows a dot.
    public private(set) var hasNewIcon = false
    /// The app cannot name icons. Only a count above this one is a new icon.
    private var highestHiddenCount = 0

    /// At login many apps start. A dot in this time is noise.
    private static let quietSecondsAfterStart: Double = 60

    public init() {}

    public var dividerLength: CGFloat {
        isHidden ? DividerLength.stretched : DividerLength.thin
    }

    public mutating func show() {
        isHidden = false
        hasNewIcon = false
    }

    /// `hiddenCount` is the number of icons on the left of the divider at this moment.
    public mutating func hide(hiddenCount: Int) {
        isHidden = true
        highestHiddenCount = max(highestHiddenCount, hiddenCount)
    }

    /// Call this one time after an app started, with the count of that moment.
    public mutating func appStarted(hiddenCount: Int, secondsSinceStart: Double) {
        // While the icons show, the user can see a new icon. The next hide takes the count.
        guard isHidden, hiddenCount > highestHiddenCount else { return }
        highestHiddenCount = hiddenCount
        if secondsSinceStart >= BarModel.quietSecondsAfterStart { hasNewIcon = true }
    }
}

/// The geometry rules of the menu bar. All frames are in screen points.
public enum BarLayout {
    /// The frames of two icons never overlap, so the left edges tell the order.
    /// A stretched divider on the right of the arrow pushes the arrow off the screen.
    public static func dividerIsLeftOfArrow(dividerFrame: CGRect, arrowFrame: CGRect) -> Bool {
        dividerFrame.minX < arrowFrame.minX
    }

    /// True when the right edge of the divider is the left edge of the arrow. No icon is between them then.
    /// The frames can differ by one point.
    public static func dividerTouchesArrow(dividerFrame: CGRect, arrowFrame: CGRect) -> Bool {
        abs(dividerFrame.maxX - arrowFrame.minX) <= 1
    }

    /// The number of icons that are fully on the left of the divider.
    public static func hiddenCount(iconFrames: [CGRect], dividerMinX: CGFloat) -> Int {
        iconFrames.filter { $0.maxX <= dividerMinX }.count
    }

    /// The menu bar of a screen, in screen points. The top edge of the screen is in the band.
    static func menuBarBand(screenFrame: CGRect, visibleFrame: CGRect, statusBarThickness: CGFloat) -> CGRect {
        // A menu bar that hides itself takes no room from the visible frame.
        let height = max(screenFrame.maxY - visibleFrame.maxY, statusBarThickness)
        return CGRect(x: screenFrame.minX, y: screenFrame.maxY - height, width: screenFrame.width, height: height + 1)
    }

    /// True when a frame of a status item is correct: its top is the top of a screen and a part of it is on that screen.
    /// A new status item has a wrong frame for about 150 ms.
    static func isInMenuBar(_ frame: CGRect, screenFrames: [CGRect]) -> Bool {
        screenFrames.contains { screen in
            frame.height > 0 && abs(frame.maxY - screen.maxY) < 1 && frame.maxX > screen.minX && frame.minX < screen.maxX
        }
    }

    /// The window frames with the same top and the same height as the divider. These are the icons of its menu bar.
    /// The window frames come from the window list: the zero is at the top of the main screen, and y grows down.
    static func frames(_ windowFrames: [CGRect], inBandOf dividerFrame: CGRect, mainScreenHeight: CGFloat) -> [CGRect] {
        let top = mainScreenHeight - dividerFrame.maxY
        return windowFrames.filter { abs($0.minY - top) < 1 && abs($0.height - dividerFrame.height) < 1 }
    }
}
