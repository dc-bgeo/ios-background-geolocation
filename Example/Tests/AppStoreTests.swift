import XCTest
@testable import BGeoExample

@MainActor
final class AppStoreTests: XCTestCase {

    // MARK: - logs cap

    func testAppendLogPastCapDropsOldestKeepsNewest() {
        let store = AppStore()
        for i in 0..<(AppStore.maxLogs + 1) {
            store.appendLog(LogLine(ts: "t\(i)", level: .info, event: "e\(i)"))
        }
        XCTAssertEqual(store.logs.count, AppStore.maxLogs)
        // The 0th log was dropped; the oldest surviving one is "e1".
        XCTAssertEqual(store.logs.first?.event, "e1")
        // The last appended log ("e1000") is the newest and must survive.
        XCTAssertEqual(store.logs.last?.event, "e\(AppStore.maxLogs)")
    }

    func testAppendLogUnderCapKeepsEverything() {
        let store = AppStore()
        store.appendLog(LogLine(ts: "t0", level: .debug, event: "a"))
        store.appendLog(LogLine(ts: "t1", level: .warn, event: "b"))
        XCTAssertEqual(store.logs.map(\.event), ["a", "b"])
    }

    // MARK: - points cap

    func testAppendPointPastCapDropsOldestKeepsNewest() {
        let store = AppStore()
        for i in 0..<(AppStore.maxPoints + 1) {
            store.appendPoint(Point(uuid: "p\(i)", latitude: 0, longitude: 0, timestamp: "t\(i)"))
        }
        XCTAssertEqual(store.points.count, AppStore.maxPoints)
        XCTAssertEqual(store.points.first?.uuid, "p1")
        XCTAssertEqual(store.points.last?.uuid, "p\(AppStore.maxPoints)")
    }

    // MARK: - clearLogs / clearTrack

    func testClearLogsEmptiesLogsWithoutTouchingPoints() {
        let store = AppStore()
        store.appendLog(LogLine(ts: "t", level: .info, event: "e"))
        store.appendPoint(Point(latitude: 1, longitude: 2, timestamp: "t"))

        store.clearLogs()

        XCTAssertTrue(store.logs.isEmpty)
        XCTAssertEqual(store.points.count, 1)
    }

    func testClearTrackEmptiesPointsWithoutTouchingLogs() {
        let store = AppStore()
        store.appendLog(LogLine(ts: "t", level: .info, event: "e"))
        store.appendPoint(Point(latitude: 1, longitude: 2, timestamp: "t"))

        store.clearTrack()

        XCTAssertTrue(store.points.isEmpty)
        XCTAssertEqual(store.logs.count, 1)
    }

    // MARK: - setStatus partial-update semantics

    func testSetStatusPreservesUntouchedFields() {
        let store = AppStore()
        store.setStatus(ready: true, enabled: true, isMoving: false, batteryLevel: 0.5)

        store.setStatus(isMoving: true)

        XCTAssertTrue(store.status.ready)
        XCTAssertTrue(store.status.enabled)
        XCTAssertTrue(store.status.isMoving)
        XCTAssertEqual(store.status.batteryLevel, 0.5)
    }

    // MARK: - defaults

    func testStatusDefaults() {
        let store = AppStore()
        XCTAssertFalse(store.status.ready)
        XCTAssertFalse(store.status.enabled)
        XCTAssertFalse(store.status.isMoving)
        XCTAssertNil(store.status.batteryLevel)
    }
}
