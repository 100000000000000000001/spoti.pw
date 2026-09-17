// The areas the redesign stripped and SGRRepaint.x keeps transparent when Spotify repaints them, each
// set by the part of the redesign that owns it.
#import <UIKit/UIKit.h>

extern __weak UIView *sgr_nowPlayingRoot;   // Redesigned/NowPlayingBar/NowPlayingBar.x, the bar
extern __weak UIView *sgr_nowPlayingCard;   // the bar's painted card, learnt from the album-colour paint
extern __weak UIView *sgr_lyricsCardRoot;   // Redesigned/Player/PlayerCards.x, the cell of the lyrics card
extern __weak UIView *sgr_lyricsPageRoot;   // Redesigned/Lyrics/LyricsPage.x
