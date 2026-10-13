import Foundation
@testable import MenubarKit

/// A clock for the tests. Time moves only when a test calls `advance(by:)`, so no test waits real seconds.
@MainActor final class FakeClock {
    private(set) var now: TimeInterval = 0
    private var waits: [Int: (end: TimeInterval, work: @MainActor () -> Void)] = [:]
    private var nextID = 0

    /// The number of waits that did not end and that nobody stopped.
    var pendingCount: Int { waits.count }

    /// Give this to the code under test in place of the real timer.
    var schedule: Schedule {
        { seconds, work in
            let id = self.nextID
            self.nextID += 1
            self.waits[id] = (self.now + seconds, work)
            return { self.waits[id] = nil }
        }
    }

    /// Moves the time forward and runs each wait that ends in this time, in the order of the ends.
    func advance(by seconds: TimeInterval) {
        let end = now + seconds
        while let next = waits.filter({ $0.value.end <= end }).min(by: { $0.value.end < $1.value.end }) {
            now = next.value.end
            waits[next.key] = nil
            next.value.work()
        }
        now = end
    }
}
