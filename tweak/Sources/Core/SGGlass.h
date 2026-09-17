// Glass panes: one UIVisualEffectView per host, kept behind the host's own content.
#import <UIKit/UIKit.h>

// UIGlassEffect made the only way that resolves its material, or a dark chrome blur before iOS 26.
UIVisualEffect *SGGlassEffect(void);
UIVisualEffectView *SGGlassFor(UIView *host, const void *key);
// Several panes on one host, addressed by index; panes past `count` are hidden by SGHideGlassFrom.
UIVisualEffectView *SGGlassAt(UIView *host, NSUInteger index);
void SGHideGlassFrom(UIView *host, NSUInteger count);
// Glass takes its shape from cornerConfiguration on iOS 26; layer.cornerRadius is the fallback.
void SGShapeGlass(UIView *glass, CGFloat radius, BOOL capsule);

// Areas kept transparent by Features/Appearance/Repaint.x, set by the features that own them.
extern __weak UIView *sg_nowPlayingRoot;
extern __weak UIView *sg_tabBarRoot;
extern __weak UIView *sg_nowPlayingCard;
extern __weak UIView *sg_lyricsCardRoot;
extern __weak UIView *sg_lyricsPageRoot;
extern __weak UIView *sg_homeRoot;          // Home/HomeGradient.x, the base surface only
extern __weak UIView *sg_npvBackdropRoot;   // NowPlaying/Player.x, the plane behind the player

// The full screen player morphs the now playing bar's own card into the cover art, so for the
// length of that animation NowPlaying/NowPlayingBar.x hands the bar back to Spotify: the flag lets
// the album colour through Repaint.x again, and the last colour it took off is kept to restore.
extern BOOL sg_nowPlayingStock;
extern CGColorRef sg_nowPlayingCardColor;
void SGRememberCardColor(CGColorRef color);
