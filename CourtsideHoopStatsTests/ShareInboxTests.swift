import XCTest
import Combine
@testable import CourtsideHoopStats

/// An invite that launches the app arrives before anything is listening
/// (#57); the inbox has to keep it until something is.
@MainActor
final class ShareInboxTests: XCTestCase {
    func testAnItemPostedBeforeAnyoneListensIsStillDelivered() {
        let box = Mailbox<String>()
        box.post("invite")

        var received: [String] = []
        let subscription = box.$pending.sink { pending in
            guard !pending.isEmpty else { return }
            received += box.take()
        }
        defer { subscription.cancel() }

        XCTAssertEqual(received, ["invite"])
        XCTAssertTrue(box.pending.isEmpty)
    }

    func testEachItemIsTakenOnce() {
        let box = Mailbox<String>()
        box.post("a")
        box.post("b")
        XCTAssertEqual(box.take(), ["a", "b"])
        XCTAssertEqual(box.take(), [])
    }
}
