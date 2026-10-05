import XCTest
@testable import BackgroundGeolocation

final class ModelDecodingTests: XCTestCase {

    /// A full Location payload in exactly the shape the engine emits.
    private func locationDictionary() -> [String: Any] {
        [
            "uuid": "abc-123",
            "timestamp": "2026-07-29T10:00:00.000Z",
            "odometer": 1234.5,
            "is_moving": true,
            "coords": [
                "latitude": 52.2297, "longitude": 21.0122, "accuracy": 12.0,
                "altitude": 110.0, "altitude_accuracy": 3.0,
                "speed": 4.2, "speed_accuracy": 0.5,
                "heading": 91.0, "heading_accuracy": 2.0,
                "ellipsoidal_altitude": 140.0,
            ],
            "activity": ["type": "in_vehicle", "confidence": 88],
            "battery": ["level": 0.62, "is_charging": false],
            "extras": ["watch": true],
        ]
    }

    func testLocationDecodesEveryFieldIncludingSnakeCaseWireKeys() {
        let location = Location(dictionary: locationDictionary())
        XCTAssertNotNil(location)
        XCTAssertEqual(location?.uuid, "abc-123")
        XCTAssertEqual(location?.odometer, 1234.5)
        XCTAssertEqual(location?.isMoving, true)
        XCTAssertEqual(location?.coords.latitude, 52.2297)
        XCTAssertEqual(location?.coords.altitudeAccuracy, 3.0)
        XCTAssertEqual(location?.coords.speedAccuracy, 0.5)
        XCTAssertEqual(location?.coords.headingAccuracy, 2.0)
        XCTAssertEqual(location?.coords.ellipsoidalAltitude, 140.0)
        XCTAssertEqual(location?.activity.type, .inVehicle)
        XCTAssertEqual(location?.activity.confidence, 88)
        XCTAssertEqual(location?.battery.level, 0.62)
        XCTAssertEqual(location?.battery.isCharging, false)
        XCTAssertEqual(location?.extras?["watch"] as? Bool, true)
    }

    func testLocationDecodesWithOnlyRequiredFields() {
        var dictionary = locationDictionary()
        dictionary["coords"] = ["latitude": 1.0, "longitude": 2.0, "accuracy": 3.0]
        dictionary.removeValue(forKey: "extras")
        let location = Location(dictionary: dictionary)
        XCTAssertNotNil(location)
        XCTAssertNil(location?.coords.altitude)
        XCTAssertNil(location?.extras)
    }

    func testLocationDecodingFailsWhenARequiredFieldIsMissing() {
        var dictionary = locationDictionary()
        dictionary.removeValue(forKey: "uuid")
        XCTAssertNil(Location(dictionary: dictionary))
    }

    func testLocationDecodesWithNSNullIsMovingAsFalseRatherThanFailing() {
        // The engine sends NSNull, not false, while a cold-started session's
        // first fixes are still in the "unconfirmed MOVING" probing window
        // (`BGGeoEngine.mm:2826`) — up to 5 minutes after `start()` by
        // default. `is_moving` must coerce to `false`, not be required,
        // or every location in that window fails to decode.
        var dictionary = locationDictionary()
        dictionary["is_moving"] = NSNull()
        let location = Location(dictionary: dictionary)
        XCTAssertNotNil(location, "an NSNull is_moving must not fail the whole decode")
        XCTAssertEqual(location?.isMoving, false)
    }

    func testLocationRawExposesTheUntouchedPayload() {
        let dictionary = locationDictionary()
        let location = Location(dictionary: dictionary)
        XCTAssertEqual(location?.raw["uuid"] as? String, "abc-123")
        XCTAssertEqual(location?.raw["is_moving"] as? Bool, true)
    }

    func testMotionChangeAcceptsAbsentLocation() {
        // Android omits `location` on the first motionchange of a session.
        let event = MotionChangeEvent(dictionary: ["isMoving": true])
        XCTAssertEqual(event?.isMoving, true)
        XCTAssertNil(event?.location)
    }

    func testMotionChangeAcceptsNSNullLocation() {
        // iOS sends NSNull in the same situation. This must not crash or fail.
        let event = MotionChangeEvent(dictionary: ["isMoving": false, "location": NSNull()])
        XCTAssertEqual(event?.isMoving, false)
        XCTAssertNil(event?.location)
    }

    func testCrashEventAcceptsNSNullLocation() {
        let event = CrashEvent(dictionary: [
            "timestamp": "2026-08-17T10:00:00.000Z",
            "peakG": 4.2,
            "impactDurationMs": 180.0,
            "preImpactSpeedMps": 12.5,
            "location": NSNull(),
        ])
        XCTAssertEqual(event?.peakG, 4.2)
        XCTAssertNil(event?.location)
    }

    func testDistractionEventAcceptsNSNullLocation() {
        let event = DistractionEvent(dictionary: [
            "timestamp": "2026-08-21T10:00:00.000Z",
            "startTimestamp": "2026-08-21T09:59:50.000Z",
            "durationSec": 10.0,
            "cause": "h",
            "location": NSNull(),
        ])
        XCTAssertEqual(event?.startTimestamp, "2026-08-21T09:59:50.000Z")
        XCTAssertEqual(event?.durationSec, 10.0)
        XCTAssertEqual(event?.cause, "h")
        XCTAssertNil(event?.location)
    }

    func testHeadingEventDecodesTheWireShape() {
        let event = HeadingEvent(dictionary: [
            "heading": 91.5,
            "accuracy": 12.0,
            "isTrue": true,
        ])
        XCTAssertEqual(event?.heading, 91.5)
        XCTAssertEqual(event?.accuracy, 12.0)
        XCTAssertEqual(event?.isTrue, true)
    }

    func testHeadingEventKeepsANegativeAccuracyRatherThanDroppingTheEvent() {
        // CoreLocation reports a NEGATIVE headingAccuracy while the compass is
        // uncalibrated. That is a real, meaningful reading the app must be
        // able to see (and grey out its compass over) — not a malformed
        // payload to drop. Whole-number `0` for `heading` must survive too:
        // due north is a valid heading, not a missing field.
        let event = HeadingEvent(dictionary: [
            "heading": 0,
            "accuracy": -1,
            "isTrue": false,
        ])
        XCTAssertEqual(event?.heading, 0)
        XCTAssertEqual(event?.accuracy, -1)
        XCTAssertEqual(event?.isTrue, false)
    }

    func testHeadingEventDropsAPayloadMissingARequiredField() {
        XCTAssertNil(HeadingEvent(dictionary: ["accuracy": 12.0, "isTrue": true]))
        XCTAssertNil(HeadingEvent(dictionary: ["heading": 91.5, "isTrue": true]))
        XCTAssertNil(HeadingEvent(dictionary: ["heading": 91.5, "accuracy": 12.0]))
        // A mistyped value is the same as absent — never coerced to a
        // fabricated default.
        XCTAssertNil(HeadingEvent(dictionary: ["heading": "91.5", "accuracy": 12.0, "isTrue": true]))
        XCTAssertNil(HeadingEvent(dictionary: ["heading": 91.5, "accuracy": 12.0, "isTrue": NSNull()]))
    }

    func testUnknownActivityTypeFallsBackToUnknownRatherThanFailing() {
        let activity = MotionActivity(dictionary: ["type": "teleporting", "confidence": 10])
        XCTAssertEqual(activity?.type, .unknown)
    }

    func testStateExposesTypedEnabledAndKeepsUnknownDiagnosticKeys() {
        let state = State(dictionary: [
            "enabled": true,
            "odometer": 42.0,
            "someFutureDiagnosticKey": 7,
        ])
        XCTAssertEqual(state.enabled, true)
        XCTAssertEqual(state["odometer"] as? Double, 42.0)
        XCTAssertEqual(state["someFutureDiagnosticKey"] as? Int, 7)
    }

    func testStateDefaultsEnabledToFalseWhenTheKeyIsAbsentRatherThanFailing() {
        // Non-failable: the engine always resolves `stateDictionary()`, never
        // rejects, so decoding must not fail even on a payload missing keys.
        let state = State(dictionary: [:])
        XCTAssertEqual(state.enabled, false)
        XCTAssertNil(state["enabled"], "the raw dictionary must not fabricate a key the engine never sent")
    }

    func testGeofenceRoundTripsThroughItsDictionary() {
        let geofence = Geofence(
            identifier: "home", radius: 150, latitude: 52.0, longitude: 21.0,
            notifyOnEntry: true, notifyOnExit: true, notifyOnDwell: false,
            loiteringDelay: 30_000, extras: ["kind": "home"]
        )
        let decoded = Geofence(dictionary: geofence.toDictionary())
        XCTAssertEqual(decoded?.identifier, "home")
        XCTAssertEqual(decoded?.radius, 150)
        XCTAssertEqual(decoded?.notifyOnDwell, false)
        XCTAssertEqual(decoded?.loiteringDelay, 30_000)
        XCTAssertEqual(decoded?.extras?["kind"] as? String, "home")
    }

    func testGeofenceDictionaryOmitsNilOptionals() {
        let geofence = Geofence(identifier: "x", radius: 100, latitude: 0, longitude: 0)
        let dictionary = geofence.toDictionary()
        XCTAssertNil(dictionary["notifyOnEntry"])
        XCTAssertNil(dictionary["loiteringDelay"])
        XCTAssertNil(dictionary["extras"])
    }

    func testGeofenceEventDecodesItsAction() {
        let event = GeofenceEvent(dictionary: [
            "identifier": "home",
            "action": "DWELL",
            "location": locationDictionary(),
        ])
        XCTAssertEqual(event?.action, .dwell)
        XCTAssertEqual(event?.identifier, "home")
    }

    func testProviderStateDecodesTypedEnums() {
        let providerState = ProviderState(dictionary: [
            "status": 3, "enabled": true, "gps": true, "network": false,
            "accuracyAuthorization": 1, "insufficientlyInUse": true,
        ])
        XCTAssertEqual(providerState.status, .always)
        XCTAssertEqual(providerState.accuracyAuthorization, .reduced)
        XCTAssertEqual(providerState.network, false)
        XCTAssertEqual(providerState.insufficientlyInUse, true)
    }

    func testProviderStateFallsBackRatherThanFailingOnAnEmptyDictionary() {
        // Non-failable, for the same reason as `State` — see above.
        let providerState = ProviderState(dictionary: [:])
        XCTAssertEqual(providerState.status, .notDetermined)
        XCTAssertEqual(providerState.enabled, false)
        XCTAssertEqual(providerState.gps, false)
        XCTAssertEqual(providerState.network, false)
        XCTAssertNil(providerState.accuracyAuthorization)
        // Android (and pre-0.15 iOS cores) never emit the key — must read false.
        XCTAssertEqual(providerState.insufficientlyInUse, false)
    }

    func testLogEntryDataDecodesAsTheParsedObjectNotAString() throws {
        // The engine JSON-parses the `data` string back into an object before
        // returning it (`BGGeoEngine.mm:718-721`); reading it with
        // `dictionary.string("data")` silently yields nil for every
        // well-formed entry. A round-tripped dictionary must come back as a
        // dictionary here, not nil.
        let entry = LogEntry(dictionary: [
            "ts": "2026-07-29T10:00:00.000Z",
            "level": 3,
            "src": "native",
            "event": "app",
            "data": ["reason": "test", "count": 2],
        ])
        XCTAssertNotNil(entry)
        let data = try XCTUnwrap(entry?.data as? [String: Any])
        XCTAssertEqual(data["reason"] as? String, "test")
        XCTAssertEqual(data["count"] as? Int, 2)
    }

    func testLocationErrorEventDecodesAStringCode() {
        // The watch-tick-failure path (BGGeoEngine.mm:2689) emits `code` as
        // a String.
        let event = LocationErrorEvent(dictionary: ["code": "408", "message": "Location request timed out"])
        XCTAssertEqual(event?.code, "408")
        XCTAssertEqual(event?.message, "Location request timed out")
    }

    func testLocationErrorEventDecodesAnNSNumberCodeAsItsIntegerString() {
        // Regression: ordinary CoreLocation failures (BGGeoEngine.mm:1308)
        // emit `code` as an NSNumber (the raw CLError code), not a String.
        // `dictionary.string("code")` alone — `as? String` — is nil for an
        // NSNumber, so this used to silently drop every one of these, which
        // is the common case this event exists to report.
        let event = LocationErrorEvent(dictionary: ["code": 1 as NSNumber, "message": "denied"])
        XCTAssertEqual(event?.code, "1")
        XCTAssertEqual(event?.message, "denied")
    }

    func testLocationErrorEventRequiresCode() {
        XCTAssertNil(LocationErrorEvent(dictionary: ["message": "no code"]))
    }

    func testHttpEventDecodes() {
        let event = HttpEvent(dictionary: ["success": false, "status": 0, "responseText": "offline"])
        XCTAssertEqual(event?.success, false)
        XCTAssertEqual(event?.status, 0)
        XCTAssertEqual(event?.responseText, "offline")
    }
}
