// The Live Activity's face: the playing track, the line being sung with the next one under it,
// and previous, play/pause and next. Built with the tweak's LiveActivityShared.swift by
// scripts/build-extension.sh.
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let spotifyGreen = Color(red: 0.12, green: 0.84, blue: 0.38)

@main
struct SGLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        SGLyricsLiveActivity()
    }
}

struct SGLyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SGLyricsAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "spotify:"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TrackView(state: context.state)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ControlsView(paused: context.state.paused)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LyricsView(state: context.state)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .foregroundStyle(spotifyGreen)
            } compactTrailing: {
                Image(systemName: context.state.paused ? "pause.fill" : "waveform")
                    .foregroundStyle(spotifyGreen)
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundStyle(spotifyGreen)
            }
            .widgetURL(URL(string: "spotify:"))
        }
    }
}

private struct LockScreenView: View {
    let state: SGLyricsAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                TrackView(state: state)
                Spacer(minLength: 8)
                ControlsView(paused: state.paused)
            }
            LyricsView(state: state)
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

private struct TrackView: View {
    let state: SGLyricsAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(state.artist)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }
}

private struct LyricsView: View {
    let state: SGLyricsAttributes.ContentState

    var body: some View {
        if !state.line.isEmpty || !state.nextLine.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if !state.line.isEmpty {
                    Text(state.line)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                if !state.nextLine.isEmpty {
                    Text(state.nextLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct ControlsView: View {
    let paused: Bool

    var body: some View {
        HStack(spacing: 18) {
            Button(intent: SGPreviousTrackIntent()) {
                Image(systemName: "backward.fill")
            }
            Button(intent: SGTogglePlaybackIntent()) {
                Image(systemName: paused ? "play.fill" : "pause.fill")
                    .font(.title2)
            }
            Button(intent: SGNextTrackIntent()) {
                Image(systemName: "forward.fill")
            }
        }
        .buttonStyle(.plain)
        .font(.title3)
        .foregroundStyle(.white)
    }
}
