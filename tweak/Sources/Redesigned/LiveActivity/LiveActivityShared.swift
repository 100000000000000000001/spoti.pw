// Compiled into both the tweak and extension/LiveActivity: ActivityKit pairs the two sides by the
// attributes' type name, so this must stay identical in both.
import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct SGLyricsAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var line: String
        var nextLine: String
        var paused: Bool
    }
}
