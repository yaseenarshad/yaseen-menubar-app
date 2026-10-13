import Foundation
import Testing
@testable import MenubarKit

/// Two copies of the app would put two arrows in the menu bar. The copy that started later quits.
@Suite struct SecondCopyTests {
    let early = Date(timeIntervalSince1970: 1000)
    let late = Date(timeIntervalSince1970: 2000)

    /// One other copy of the app that runs.
    func copy(_ pid: pid_t, _ launchDate: Date?) -> [(pid: pid_t, launchDate: Date?)] { [(pid, launchDate)] }

    @Test func theCopyThatStartedLaterQuits() {
        #expect(AppController.isSecondCopy(pid: 200, launchDate: late, others: copy(100, early)))
        #expect(!AppController.isSecondCopy(pid: 100, launchDate: early, others: copy(200, late)))
        #expect(!AppController.isSecondCopy(pid: 100, launchDate: early, others: []))
    }

    // Two copies that started at the same moment, or with no known moment: only the higher process id quits.
    @Test func oneCopyAlwaysStays() {
        #expect(AppController.isSecondCopy(pid: 200, launchDate: early, others: copy(100, early)))
        #expect(!AppController.isSecondCopy(pid: 100, launchDate: early, others: copy(200, early)))
        #expect(AppController.isSecondCopy(pid: 200, launchDate: nil, others: copy(100, early)))
        #expect(!AppController.isSecondCopy(pid: 100, launchDate: nil, others: copy(200, nil)))
    }
}
