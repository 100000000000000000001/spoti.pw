// Compiled into both the tweak and extension/LiveActivity: ActivityKit pairs the two sides by the
// attributes' type name and App Intents by the intent's, so these must stay identical in both.
import ActivityKit
import AppIntents
import Foundation

@available(iOS 16.1, *)
struct SGLyricsAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var line: String
        var nextLine: String
        var paused: Bool
    }
}

// A LiveActivityIntent runs in the app's process, where the tweak turns the notification into a player call.
let SGLiveActivityCommandNotification = Notification.Name("SGLiveActivityCommand")

@available(iOS 17.0, *)
private func sendPlayerCommand(_ command: String) {
    NotificationCenter.default.post(name: SGLiveActivityCommandNotification, object: command)
}

@available(iOS 17.0, *)
struct SGPreviousTrackIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Previous track"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        sendPlayerCommand("previous")
        return .result()
    }
}

@available(iOS 17.0, *)
struct SGTogglePlaybackIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Play or pause"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        sendPlayerCommand("toggle")
        return .result()
    }
}

@available(iOS 17.0, *)
struct SGNextTrackIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next track"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        sendPlayerCommand("next")
        return .result()
    }
}
