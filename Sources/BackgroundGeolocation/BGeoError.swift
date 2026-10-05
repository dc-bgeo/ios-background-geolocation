import Foundation

/// Typed wrapper over the engine's `(code, message)` reject pairs. Unrecognised
/// codes map to `.unknown` rather than being swallowed, so new engine codes
/// remain diagnosable.
///
/// The four `license*` cases are deprecated: the SDK is free, the engine no
/// longer performs a license check, and nothing produces these codes any
/// more. They are kept only so existing `switch`es keep compiling.
public enum BGeoError: Error, Equatable {
    /// Deprecated — never emitted (the SDK needs no license key).
    @available(*, deprecated, message: "No longer emitted — the SDK is free and needs no license key. Will be removed in the next major.")
    case licenseMissing(message: String)
    /// Deprecated — never emitted (the SDK needs no license key).
    @available(*, deprecated, message: "No longer emitted — the SDK is free and needs no license key. Will be removed in the next major.")
    case licenseInvalid(message: String)
    /// Deprecated — never emitted (the SDK needs no license key).
    @available(*, deprecated, message: "No longer emitted — the SDK is free and needs no license key. Will be removed in the next major.")
    case licenseExpired(message: String)
    /// Deprecated — never emitted (the SDK needs no license key).
    @available(*, deprecated, message: "No longer emitted — the SDK is free and needs no license key. Will be removed in the next major.")
    case licenseAppMismatch(message: String)
    case disabled(message: String)
    case notFound(message: String)
    case invalidGeofence(message: String)
    case unknown(code: String, message: String)

    public init(code: String, message: String) {
        switch code {
        case "LICENSE_MISSING": self = .licenseMissing(message: message)
        case "LICENSE_INVALID": self = .licenseInvalid(message: message)
        case "LICENSE_EXPIRED": self = .licenseExpired(message: message)
        case "LICENSE_APP_MISMATCH": self = .licenseAppMismatch(message: message)
        case "DISABLED": self = .disabled(message: message)
        case "NOT_FOUND": self = .notFound(message: message)
        case "INVALID_GEOFENCE": self = .invalidGeofence(message: message)
        default: self = .unknown(code: code, message: message)
        }
    }

    public var code: String {
        switch self {
        case .licenseMissing: return "LICENSE_MISSING"
        case .licenseInvalid: return "LICENSE_INVALID"
        case .licenseExpired: return "LICENSE_EXPIRED"
        case .licenseAppMismatch: return "LICENSE_APP_MISMATCH"
        case .disabled: return "DISABLED"
        case .notFound: return "NOT_FOUND"
        case .invalidGeofence: return "INVALID_GEOFENCE"
        case .unknown(let code, _): return code
        }
    }

    public var message: String {
        switch self {
        case .licenseMissing(let message),
             .licenseInvalid(let message),
             .licenseExpired(let message),
             .licenseAppMismatch(let message),
             .disabled(let message),
             .notFound(let message),
             .invalidGeofence(let message):
            return message
        case .unknown(_, let message):
            return message
        }
    }
}

extension BGeoError: LocalizedError {
    public var errorDescription: String? {
        "\(code): \(message)"
    }
}
