import XCTest
@testable import BGeoExample

/// Covers `HistoryLoader.filterPointsByRange` (`Sources/History.swift`).
@MainActor
final class HistoryTests: XCTestCase {

    private func point(_ iso: String) -> Point {
        Point(latitude: 1, longitude: 2, timestamp: iso)
    }

    // MARK: - filterPointsByRange (pure)

    func testFilterPointsByRangeKeepsPointsInsideBothBounds() {
        let points = [point("2026-07-01T00:00:00Z"), point("2026-07-15T00:00:00Z"), point("2026-08-01T00:00:00Z")]
        let from = parseISODate("2026-07-10T00:00:00Z")
        let to = parseISODate("2026-07-20T00:00:00Z")
        let result = HistoryLoader.filterPointsByRange(points, from: from, to: to)
        XCTAssertEqual(result.map(\.timestamp), ["2026-07-15T00:00:00Z"])
    }

    func testFilterPointsByRangeWithNilBoundsIsUnbounded() {
        let points = [point("2026-07-01T00:00:00Z"), point("2026-08-01T00:00:00Z")]
        let result = HistoryLoader.filterPointsByRange(points, from: nil, to: nil)
        XCTAssertEqual(result.count, 2)
    }

    func testFilterPointsByRangeDropsUnparsableTimestamps() {
        let points = [point("not-a-date")]
        let result = HistoryLoader.filterPointsByRange(points, from: nil, to: parseISODate("2026-01-01T00:00:00Z"))
        XCTAssertTrue(result.isEmpty)
    }
}
