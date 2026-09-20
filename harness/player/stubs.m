// What the player harness does not compile: the Kit's hooks (SGRAccent.x, SGRRepaint.x, SGRBridges.x),
// the rest of the player's hooks, the lyrics store and the haptics. Everything here answers the way the
// phone would for one paused track with lyrics, so the redesign's own code is what is being looked at.
#import <UIKit/UIKit.h>
#import "Shared/Lyrics/Lyrics.h"
#import "Headers/SPTPlayer.h"

#pragma mark - SGRAccent.x, SGRRepaint.x

UIColor *SGRAccentColor(void) { return nil; }
__weak UIView *sgr_nowPlayingRoot = nil;
__weak UIView *sgr_nowPlayingCard = nil;
__weak UIView *sgr_lyricsPageRoot = nil;
__weak UIView *sgr_playlistRoot = nil;

#pragma mark - Shared/Player/PlayerEvents.x

NSString *const SGPlayerTransitionNotification = @"spotifyglass.playerTransition";
NSString *const SGPlayerTransitionEndedNotification = @"spotifyglass.playerTransitionEnded";
CFTimeInterval SGPlayerTransitionEnds(void) { return 0; }

#pragma mark - Shared/Player/PlayerState.x

NSString *SGURIString(id uri) {
    if ([uri isKindOfClass:NSString.class]) return uri;
    if ([uri isKindOfClass:NSURL.class]) return ((NSURL *)uri).absoluteString;
    return nil;
}
void SGAddPlayerStateObserver(id observer) {}
SPTPlayerState *SGPlayerState(void) { return nil; }

#pragma mark - Redesigned/Kit/SGRBridges.x

NSNotificationName const SGRNowPlayingArtworkDidChangeNotification = @"spotifyglass.redesign.artwork";
static UIImage *sg_artwork;
void SGRSetNowPlayingArtwork(UIImage *image, NSString *trackURI, NSInteger quality) { sg_artwork = image; }
UIImage *SGRNowPlayingArtwork(NSString **trackURI, NSString **identity) {
    if (trackURI) *trackURI = @"spotify:track:harness";
    if (identity) *identity = @"harness";
    return sg_artwork;
}
void SGRHarnessSetArtwork(UIImage *image) { sg_artwork = image; }
BOOL SGRPlayerIsTransitioning(void) { return NO; }
void SGRObservePlayerTransition(id owner, void (^began)(id owner), void (^ended)(id owner)) {}

#pragma mark - Redesigned/Player/PlayerControls.x

void SGRPlayerVanish(UIView *view) {
    view.alpha = 0;
    view.userInteractionEnabled = NO;
    view.accessibilityElementsHidden = YES;
}

#pragma mark - Shared/Haptics

void SGPlayFeedback(NSInteger feedback) {}
void SGPrepareFeedback(NSInteger feedback) {}

#pragma mark - Shared/LyricsSources

NSString *SGLyricsCreditFor(NSString *trackID) { return @"the harness"; }

#pragma mark - Shared/Lyrics/KaraokeSource.x

static NSArray<SGKaraokeLine *> *sg_lines;
static NSString *sg_track = @"harness";
static NSInteger sg_position;
static CFTimeInterval sg_started;

NSString *SGKaraokePlayingTrack(void) { return sg_track; }
NSArray<SGKaraokeLine *> *SGKaraokeLinesForTrack(NSString *trackID) { return sg_lines; }
void SGKaraokeKeepLines(NSString *trackID, NSArray<SGKaraokeLine *> *lines) { sg_lines = lines; }
void SGKaraokeRequestLyrics(NSString *trackID) {}
id SGKaraokePlayer(void) { return nil; }
SPTPlayerTrack *SGKaraokeTrackFor(NSString *trackID) { return nil; }
void SGKaraokeRememberTrack(SPTPlayerTrack *track) {}

// The song runs on from the moment the harness started it, so the sweep is alive in a screenshot.
NSInteger SGKaraokePositionMs(void) {
    if (!sg_started) return sg_position;
    return sg_position + (NSInteger)((CACurrentMediaTime() - sg_started) * 1000);
}
void SGKaraokeSeek(NSInteger ms) {
    sg_position = ms;
    sg_started = CACurrentMediaTime();
}
void SGRHarnessPlayFrom(NSInteger ms) { SGKaraokeSeek(ms); }
