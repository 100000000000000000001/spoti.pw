// The redesign's Live Activity (Mod Settings > Player > Lyrics): the line being sung, with the next one
// under it, on the lock screen and in the Dynamic Island (iOS 17+).
//
//     LiveActivity.x              polls the player, sends the activity a new state when what it shows changes
//     LiveActivityBridge.swift    ActivityKit, which is Swift only
//     LiveActivityShared.swift    the attributes, compiled into the extension too
//     LiveActivitySettings.m      the Lyrics page's row
//
// The widget is extension/LiveActivity, built into the IPA by scripts/build-extension.sh. The lines and
// the clock come from Shared/Lyrics. The switch applies at once: iOS lets an activity start only while
// the app is in front, which it is when the switch is flipped.
// Threading: main thread only.
#import <Foundation/Foundation.h>

#define SGRKeyLiveActivity @"spotifyglass.redesign.liveActivity"

// From the switch: starts following the player (and the activity, the app being in front) or ends both.
void SGRSetLiveActivityEnabled(BOOL on);

@class SGModRow;
// The Live Activity row of the Lyrics page.
SGModRow *SGRLiveActivityRow(void);
