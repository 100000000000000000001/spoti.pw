// What the redesigned screens read from Spotify and ask of it, through one hook each, so no screen
// hooks the player a second time.
//
// Player state is Shared/Player/PlayerState.h's, imported here so a redesigned screen needs one header.
// Artwork: the now playing bar's 40pt cover (trees/clean/artist/01.txt: id=SPTNowPlayingBar > Encore.ImageView >
// UIImageView 40x40), read after the bar's layout and after a track change; installed while the player
// is redesigned. Screens publish better copies of their own (the player's cover).
//
// Threading: everything here is main thread only; the player's reports are moved onto it.
#import <UIKit/UIKit.h>
#import "Headers/SPTPlayer.h"
#import "Shared/Player/PlayerState.h"

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

#pragma mark - the player's open and close

// While the full screen player opens or closes (Shared/Player/PlayerEvents.x announces it).
BOOL SGRPlayerIsTransitioning(void);
// SGPlayerTransitionNotification and SGPlayerTransitionEndedNotification as blocks, for as long as
// `owner` lives. The blocks are handed the owner so they need not capture it.
void SGRObservePlayerTransition(id owner, void (^began)(id owner), void (^ended)(id owner));
