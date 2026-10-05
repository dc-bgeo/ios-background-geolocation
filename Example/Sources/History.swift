// History source for the Map screen's from/to range: the local session
// buffer filtered by timestamp.
//
// Swift port of `react-native/example/src/history.ts`; `flutter/example/lib/
// src/history.dart` is the same port for Flutter.
//
// The server-history branch (`/device/locations` on the linked debug
// console) was removed with the console itself; only the local filter
// remains.
import Foundation

public enum HistoryLoader {
    /// Pure: `history.ts`'s `filterPointsByRange`.
    public static func filterPointsByRange(_ points: [Point], from: Date?, to: Date?) -> [Point] {
        points.filter { p in
            guard let t = parseISODate(p.timestamp) else { return false }
            if let from, t < from { return false }
            if let to, t > to { return false }
            return true
        }
    }
}
