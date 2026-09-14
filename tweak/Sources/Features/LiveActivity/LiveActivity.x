// Polls the player and pushes a new state to the activity only when what it shows changes: a new
// line, track or pause. Spotify keeps playing in the background, so the timer keeps running there too.
// The activity is started only while the app is in front, the one place ActivityKit allows it.
#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "LiveActivity.h"
#import "Features/Karaoke/Karaoke.h"
#import "Headers/SPTPlayer.h"

API_AVAILABLE(ios(17.0))
@interface SGLiveActivityBridge : NSObject
@property (class, nonatomic, readonly) BOOL isShowing;
+ (void)showWithTitle:(NSString *)title artist:(NSString *)artist line:(NSString *)line nextLine:(NSString *)nextLine paused:(BOOL)paused;
+ (void)end;
@end

static const NSTimeInterval kTick = 0.25;
// Past a line's sung end by this much, with the next line at least this far off, the line gives way to a note.
static const NSInteger kBreakMs = 4000;
// Seconds between attempts to start one, so a refused request (activities turned off) is not retried every tick.
static const NSTimeInterval kStartRetry = 10;

static NSString *sg_shown;
static NSString *sg_missingLyrics;
static NSDate *sg_lastStart;

static NSString *textOf(SGKaraokeLine *line) {
    return [[line.words valueForKey:@"text"] componentsJoinedByString:@" "] ?: @"";
}

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
    NSString *line = @"", *next = index + 1 < (NSInteger)lines.count ? textOf(lines[index + 1]) : @"";
    if (index >= 0) {
        SGKaraokeLine *current = lines[index];
        BOOL nextFarOff = index + 1 == (NSInteger)lines.count || lines[index + 1].start - position > kBreakMs;
        line = position > current.end + kBreakMs && nextFarOff ? @"♪" : textOf(current);
    }

    NSString *artist = track.artistName ?: @"";
    NSString *shown = [@[track.trackTitle, artist, line, next, state.isPaused ? @"1" : @"0"] componentsJoinedByString:@"\n"];
    if (SGLiveActivityBridge.isShowing) {
        if ([shown isEqualToString:sg_shown]) return;
    } else {
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
        if (sg_lastStart && -sg_lastStart.timeIntervalSinceNow < kStartRetry) return;
        sg_lastStart = [NSDate date];
    }
    sg_shown = shown;
    [SGLiveActivityBridge showWithTitle:track.trackTitle artist:artist line:line nextLine:next paused:state.isPaused];
}

static void runCommand(NSString *command) {
    id<SPTPlayer> player = SGKaraokePlayer();
    id result = nil;
    if ([command isEqualToString:@"toggle"]) {
        result = player.state.isPaused ? [player resume:nil] : [player pause:nil];
    } else if ([command isEqualToString:@"next"]) {
        result = [player skipToNextTrackWithOptions:nil];
    } else if ([command isEqualToString:@"previous"]) {
        result = [player skipToPreviousTrackWithOptions:nil];
    }
    SGLog(@"live activity: %@ -> %@ (player %@)", command, result, player ? NSStringFromClass([player class]) : @"nil");
}

%ctor {
    if (@available(iOS 17.0, *)) {
        if (!SGFlag(SGKeyLiveActivity, NO)) {
            dispatch_async(dispatch_get_main_queue(), ^{ [SGLiveActivityBridge end]; });
            return;
        }
        [NSNotificationCenter.defaultCenter addObserverForName:@"SGLiveActivityCommand" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            runCommand(note.object);
        }];
        NSTimer *timer = [NSTimer timerWithTimeInterval:kTick repeats:YES block:^(NSTimer *t) { tick(); }];
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
        SGLog(@"live activity: on");
    }
}
