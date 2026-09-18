// Polls the player and sends the activity a new state only when what it shows changes: a new line or
// a pause. Spotify keeps playing in the background, so the timer keeps running there too.
// The activity is started only while the app is in front, the one place ActivityKit allows it.
#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Headers/SPTPlayer.h"
#import "Shared/Lyrics/Lyrics.h"
#import "LiveActivity.h"

API_AVAILABLE(ios(17.0))
@interface SGRLiveActivityBridge : NSObject
@property (class, nonatomic, readonly) BOOL isShowing;
+ (void)showWithLine:(NSString *)line nextLine:(NSString *)nextLine paused:(BOOL)paused;
+ (void)end;
@end

static const NSTimeInterval kTick = 0.25;
// Past a line's sung end by this much, with the next line at least this far off, the line gives way to a note.
static const NSInteger kBreakMs = 4000;
// Seconds between attempts to start one, so a refused request (activities turned off) is not retried every tick.
static const NSTimeInterval kStartRetry = 10;

static NSTimer *sg_timer;
static NSString *sg_shown;
static NSString *sg_missingLyrics;
static NSDate *sg_lastStart;

static void tick(void) API_AVAILABLE(ios(17.0)) {
    id<SPTPlayer> player = SGKaraokePlayer();
    SPTPlayerState *state = player.state;
    SPTPlayerTrack *track = state.track;
    if (!track.trackTitle.length) return;

    NSString *trackID = SGKaraokePlayingTrack();
    NSArray<SGKaraokeLine *> *lines = SGKaraokeLinesForTrack(trackID);
    if (!lines) {
        SGKaraokeRequestLyrics(trackID);
        if (trackID && ![trackID isEqualToString:sg_missingLyrics]) {
            sg_missingLyrics = trackID;
            SGLog(@"live activity: no lyrics yet for %@", trackID);
        }
    }

    NSInteger position = SGKaraokePositionMs();
    NSInteger index = -1;
    while (index + 1 < (NSInteger)lines.count && lines[index + 1].start <= position) index++;
    // Before the first line, between lines and without lyrics at all, a note holds the place.
    NSString *line = @"♪", *next = index + 1 < (NSInteger)lines.count ? SGKaraokeLineText(lines[index + 1]) : @"";
    if (index >= 0) {
        SGKaraokeLine *current = lines[index];
        BOOL nextFarOff = index + 1 == (NSInteger)lines.count || lines[index + 1].start - position > kBreakMs;
        line = position > current.end + kBreakMs && nextFarOff ? @"♪" : SGKaraokeLineText(current);
    }

    NSString *shown = [@[line, next, state.isPaused ? @"1" : @"0"] componentsJoinedByString:@"\n"];
    if (SGRLiveActivityBridge.isShowing) {
        if ([shown isEqualToString:sg_shown]) return;
    } else {
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
        if (sg_lastStart && -sg_lastStart.timeIntervalSinceNow < kStartRetry) return;
        sg_lastStart = [NSDate date];
    }
    sg_shown = shown;
    [SGRLiveActivityBridge showWithLine:line nextLine:next paused:state.isPaused];
}

void SGRSetLiveActivityEnabled(BOOL on) {
    if (!SGRedesignedUI()) return;
    if (@available(iOS 17.0, *)) {
        [sg_timer invalidate];
        sg_timer = nil;
        sg_shown = nil;
        sg_lastStart = nil;
        if (!on) {
            [SGRLiveActivityBridge end];
            SGLog(@"live activity: off");
            return;
        }
        sg_timer = [NSTimer timerWithTimeInterval:kTick repeats:YES block:^(NSTimer *t) { tick(); }];
        [NSRunLoop.mainRunLoop addTimer:sg_timer forMode:NSRunLoopCommonModes];
        SGLog(@"live activity: on");
    }
}

%ctor {
    if (!SGRedesignedUI()) return;
    if (@available(iOS 17.0, *)) {
        BOOL on = SGFlag(SGRKeyLiveActivity, NO);
        // Off, one left from a launch before the switch went off is ended.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (on) SGRSetLiveActivityEnabled(YES);
            else [SGRLiveActivityBridge end];
        });
    }
}
