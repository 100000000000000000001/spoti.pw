// ActivityKit is Swift only, so LiveActivity.x reaches it through this class.
import ActivityKit
import Foundation
import os

@available(iOS 17.0, *)
@objc(SGLiveActivityBridge)
public final class SGLiveActivityBridge: NSObject {
    private static let log = Logger(subsystem: "spotifyglass", category: "live activity")

    private static var current: Activity<SGLyricsAttributes>? {
        Activity<SGLyricsAttributes>.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    @objc public static var isShowing: Bool { current != nil }

    // A new activity can only be requested while the app is in the foreground; an update works from the background.
    @objc public static func show(title: String, artist: String, line: String, nextLine: String, paused: Bool) {
        let state = SGLyricsAttributes.ContentState(title: title, artist: artist, line: line, nextLine: nextLine, paused: paused)
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity = current {
            Task { await activity.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.notice("[spotifyglass] live activity: activities are off for this app")
            return
        }
        do {
            let activity = try Activity.request(attributes: SGLyricsAttributes(), content: content, pushType: nil)
            log.notice("[spotifyglass] live activity: started \(activity.id, privacy: .public)")
        } catch {
            log.error("[spotifyglass] live activity: request failed: \(String(describing: error), privacy: .public)")
        }
    }

    @objc public static func end() {
        for activity in Activity<SGLyricsAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
