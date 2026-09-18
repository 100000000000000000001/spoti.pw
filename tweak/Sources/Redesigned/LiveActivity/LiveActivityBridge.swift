// ActivityKit is Swift only, so LiveActivity.x reaches it through this class.
import ActivityKit
import Foundation
import os

@available(iOS 17.0, *)
@objc(SGRLiveActivityBridge)
public final class SGRLiveActivityBridge: NSObject {
    private static let log = Logger(subsystem: "spotifyglass", category: "live activity")

    private static var current: Activity<SGLyricsAttributes>? {
        Activity<SGLyricsAttributes>.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    @objc public static var isShowing: Bool { current != nil }

    // A new activity can only be requested while the app is in the foreground; an update works from the background.
    // One call per new state. View and tab are SGRLiveActivityView's and SGRLiveActivityTab's values;
    // titles, artists and URIs pair up by index, the tracks up next; timerEnd is nil without a timer.
    @objc public static func show(view: Int, paused: Bool, line: String, nextLine: String,
                                  titles: [String], artists: [String], uris: [String],
                                  tab: Int, title: String, artist: String, shuffle: Bool, repeatMode: Int,
                                  timerEnd: Date?, timerEndOfTrack: Bool) {
        let tracks = titles.indices.map {
            SGLyricsAttributes.Track(title: titles[$0], artist: artists[$0], uri: uris[$0])
        }
        let state = SGLyricsAttributes.ContentState(
            view: SGLyricsAttributes.View(rawValue: view) ?? .lyrics, paused: paused,
            line: line, nextLine: nextLine, tracks: tracks,
            tab: SGLyricsAttributes.Tab(rawValue: tab) ?? .controls, title: title, artist: artist,
            shuffle: shuffle, repeatMode: repeatMode, timerEnd: timerEnd, timerEndOfTrack: timerEndOfTrack)
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
