import XCTest
@testable import BGeoExample
import BackgroundGeolocation

@MainActor
final class GeofencesTests: XCTestCase {
    var store: AppStore!

    private let home = Geofence(identifier: "home", radius: 200, latitude: 1, longitude: 2)
    private let office = Geofence(identifier: "office", radius: 100, latitude: 3, longitude: 4)

    override func setUp() {
        super.setUp()
        store = AppStore()
    }

    // MARK: - refresh()

    func testRefreshSetsStoreFromTheSdkSet() async {
        let geofences = Geofences(store: store)
        geofences.getGeofencesCall = { [self.home, self.office] }

        await geofences.refresh()

        XCTAssertEqual(store.geofences.map(\.identifier), ["home", "office"])
    }

    // MARK: - add()

    func testAddCallsSdkThenRefreshes() async throws {
        let geofences = Geofences(store: store)
        var callOrder: [String] = []
        var addedGeofence: Geofence?
        geofences.addGeofenceCall = { g in callOrder.append("add"); addedGeofence = g }
        geofences.getGeofencesCall = { callOrder.append("get"); return [self.home] }

        try await geofences.add(home)

        XCTAssertEqual(addedGeofence?.identifier, "home")
        XCTAssertEqual(callOrder, ["add", "get"], "the SDK call must run, and the refresh's getGeofences after it")
        XCTAssertEqual(store.geofences.map(\.identifier), ["home"])
    }

    func testAddFailureDoesNotRefresh() async {
        struct Boom: Error {}
        let geofences = Geofences(store: store)
        geofences.addGeofenceCall = { _ in throw Boom() }
        var refreshRan = false
        geofences.getGeofencesCall = { refreshRan = true; return [] }

        do {
            try await geofences.add(home)
            XCTFail("expected add() to rethrow the SDK's error")
        } catch is Boom {
            // expected
        } catch {
            XCTFail("wrong error type: \(error)")
        }

        XCTAssertFalse(refreshRan, "refresh() must not run after a failed SDK call")
        XCTAssertTrue(store.geofences.isEmpty)
    }

    // MARK: - remove()

    func testRemoveCallsSdkThenRefreshes() async throws {
        let geofences = Geofences(store: store)
        var callOrder: [String] = []
        var removedIdentifier: String?
        geofences.removeGeofenceCall = { id in callOrder.append("remove"); removedIdentifier = id }
        geofences.getGeofencesCall = { callOrder.append("get"); return [self.office] }

        try await geofences.remove(identifier: "home")

        XCTAssertEqual(removedIdentifier, "home")
        XCTAssertEqual(callOrder, ["remove", "get"])
        XCTAssertEqual(store.geofences.map(\.identifier), ["office"])
    }

    func testRemoveFailureDoesNotRefresh() async {
        struct Boom: Error {}
        let geofences = Geofences(store: store)
        geofences.removeGeofenceCall = { _ in throw Boom() }
        var refreshRan = false
        geofences.getGeofencesCall = { refreshRan = true; return [] }

        do {
            try await geofences.remove(identifier: "home")
            XCTFail("expected remove() to rethrow the SDK's error")
        } catch is Boom {
            // expected
        } catch {
            XCTFail("wrong error type: \(error)")
        }

        XCTAssertFalse(refreshRan)
    }

    // MARK: - removeAll()

    func testRemoveAllCallsSdkThenRefreshes() async throws {
        let geofences = Geofences(store: store)
        var callOrder: [String] = []
        geofences.removeGeofencesCall = { callOrder.append("removeAll") }
        geofences.getGeofencesCall = { callOrder.append("get"); return [] }

        try await geofences.removeAll()

        XCTAssertEqual(callOrder, ["removeAll", "get"])
        XCTAssertTrue(store.geofences.isEmpty)
    }

    func testRemoveAllFailureDoesNotRefresh() async {
        struct Boom: Error {}
        let geofences = Geofences(store: store)
        geofences.removeGeofencesCall = { throw Boom() }
        var refreshRan = false
        geofences.getGeofencesCall = { refreshRan = true; return [] }

        do {
            try await geofences.removeAll()
            XCTFail("expected removeAll() to rethrow the SDK's error")
        } catch is Boom {
            // expected
        } catch {
            XCTFail("wrong error type: \(error)")
        }

        XCTAssertFalse(refreshRan)
    }

    // MARK: - geofenceschange.off regression guard (engine 0.13.1 / core 24cac4f)
    //
    // Before the fix, the engine's `geofenceschange.off` entries for a
    // removed geofence carried only `identifier` — no lat/lng/radius. The
    // SDK's own decoder (`Geofence.init?(dictionary:)`, `Models.swift`)
    // correctly treats those three fields as required and drops any record
    // missing them, so a malformed `off` entry silently vanished via
    // `compactMap` and the app never learned a fence had been removed. This
    // is the consumer-side guard for the fix: it decodes the wire shape the
    // fixed engine (0.13.1) actually emits and asserts the coordinates
    // survive, using nothing but the SDK's public `GeofencesChangeEvent`/
    // `Geofence` initialisers — no `@testable` reach into engine internals,
    // because none is needed or available from this package.

    func testGeofencesChangeOffEntryDecodesWithCoordinatesIntact() throws {
        let payload: [String: Any] = [
            "on": [],
            "off": [
                [
                    "identifier": "home",
                    "radius": 150.0,
                    "latitude": 52.52,
                    "longitude": 13.405,
                    "notifyOnEntry": true,
                    "notifyOnExit": true,
                ],
            ],
        ]

        let event = try XCTUnwrap(GeofencesChangeEvent(dictionary: payload))

        XCTAssertEqual(event.off.count, 1, "the removed fence must decode, not be dropped")
        let removed = try XCTUnwrap(event.off.first)
        XCTAssertEqual(removed.identifier, "home")
        XCTAssertEqual(removed.latitude, 52.52)
        XCTAssertEqual(removed.longitude, 13.405)
        XCTAssertEqual(removed.radius, 150)
    }

    /// Negative control: documents the PRE-FIX wire shape (identifier only)
    /// and confirms the decoder's behaviour on it is "drop, don't crash" —
    /// proving the positive test above is actually exercising the coordinate
    /// fields, not a decoder that accepts anything. If this ever starts
    /// decoding a coordinate-less record, the requirement in
    /// `Geofence.init?(dictionary:)` that let the fix work has regressed.
    func testGeofencesChangeOffEntryMissingCoordinatesIsDroppedNotCrashed() throws {
        let payload: [String: Any] = [
            "on": [],
            "off": [["identifier": "home"]],
        ]

        let event = try XCTUnwrap(GeofencesChangeEvent(dictionary: payload))

        XCTAssertTrue(event.off.isEmpty, "a coordinate-less off entry must be dropped, matching the pre-fix decoder contract")
    }
}
