// What the harness does not compile: the accent hook (SGRAccent.x) and the repaint hook (SGRRepaint.x).
#import <UIKit/UIKit.h>
UIColor *SGRAccentColor(void) { return nil; }
__weak UIView *sgr_nowPlayingRoot = nil;
__weak UIView *sgr_nowPlayingCard = nil;
__weak UIView *sgr_lyricsCardRoot = nil;
__weak UIView *sgr_lyricsPageRoot = nil;
__weak UIView *sgr_playlistRoot = nil;
__weak UIView *sgr_albumRoot = nil;
