// What the redesigned screens read from Spotify and ask of it, through one hook each, so no screen
// hooks the player or the link dispatcher a second time.
//
// Player state: -[_TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation player:stateDidChange:]
// (objc-methods.txt:60654), the now playing platform's own player observer, and until that has reported,
// an observer of the Kit's added to the first SPTEsperantoPlayer the app adds one to
// (-[SPTEsperantoPlayer addPlayerObserver:], :35729). Installed while any screen is redesigned.
// Artwork: the now playing bar's 40pt cover (trees/clean/artist/01.txt: id=SPTNowPlayingBar > Encore.ImageView >
// UIImageView 40x40), read after the bar's layout and after a track change; installed while the player
// is redesigned. Screens publish better copies of their own (the player's cover).
// Links: -[SPTLinkDispatcherImplementation setMainUILoaded:] (:38809), the last call of the singleton's
// setup, always installed: the Navbar's own tabs open through it too.
//
// Threading: everything here is main thread only; the player's reports are moved onto it.
#import <UIKit/UIKit.h>
#import "Headers/SPTPlayer.h"

// A URI Spotify types as id (NSURL or NSString) as a string; nil for anything else.
NSString *SGRURIString(id uri);

#pragma mark - player state

@protocol SGRPlayerStateObserver <NSObject>
// Called when the track, the context, paused, playing, loading or shuffle changed, not for position.
- (void)playerStateDidChange:(SPTPlayerState *)state;
@end
// Observers are held weakly and need no removal.
void SGRAddPlayerStateObserver(id<SGRPlayerStateObserver> observer);
// The last state reported, nil before the player has reported one.
SPTPlayerState *SGRPlayerState(void);

#pragma mark - now playing artwork

typedef NS_ENUM(NSInteger, SGRArtworkQuality) {
    SGRArtworkQualityLow,    // the now playing bar's 40pt cover
    SGRArtworkQualityHigh,   // the player's own cover
};
// Posted when the artwork changes, object nil, userInfo image, trackURI and quality.
extern NSNotificationName const SGRNowPlayingArtworkDidChangeNotification;
// A lower quality image for the track already published is ignored, as is the same image again.
void SGRSetNowPlayingArtwork(UIImage *image, NSString *trackURI, SGRArtworkQuality quality);
// The last artwork published; `trackURI` and `identity` (URI and quality, for
// -[SGRArtworkField setArtwork:identity:animated:]) are filled when asked for.
UIImage *SGRNowPlayingArtwork(NSString **trackURI, NSString **identity);

#pragma mark - links

// Opens a spotify: URI the way the app opens a link of its own. NO before the dispatcher is set up or
// for a nil URI.
BOOL SGROpenURI(NSURL *uri);
id SGRLinkDispatcher(void);   // SPTLinkDispatcherImplementation, nil until it is set up

#pragma mark - the player's open and close

// While the full screen player opens or closes (NowPlaying/NowPlayingBar.x announces it).
BOOL SGRPlayerIsTransitioning(void);
// SGPlayerTransitionNotification and SGPlayerTransitionEndedNotification as blocks, for as long as
// `owner` lives. The blocks are handed the owner so they need not capture it.
void SGRObservePlayerTransition(id owner, void (^began)(id owner), void (^ended)(id owner));
