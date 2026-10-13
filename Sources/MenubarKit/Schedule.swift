import Foundation

/// Stops a wait before it ends.
typealias Cancel = @MainActor () -> Void
/// Runs the work one time after the seconds. The tests give a fake clock here.
typealias Schedule = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Cancel

enum RealClock {
    /// One timer that does not repeat. The app has no other type of timer.
    @MainActor static let schedule: Schedule = { seconds, work in
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            MainActor.assumeIsolated { work() }
        }
        // The exact moment is not important. A tolerance lets macOS join this timer with others.
        timer.tolerance = seconds / 10
        return { timer.invalidate() }
    }
}
