import XCTest
@testable import VCS

final class VCSEntryTests: XCTestCase {
    func testVCSRun() {
        // VCS.run() prints to stdout — verify no crash
        VCS.run()
    }
}
