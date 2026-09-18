// The Live Activity's face: the line being sung with the next one under it, and nothing else. Built
// with the tweak's LiveActivityShared.swift by scripts/build-extension.sh.
import ActivityKit
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
            LyricsView(state: context.state)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .foregroundStyle(.white)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "spotify:"))
        } dynamicIsland: { context in
            DynamicIsland {
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

private struct LyricsView: View {
    let state: SGLyricsAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.line)
                .font(.title3.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if !state.nextLine.isEmpty {
                Text(state.nextLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
    }
}
