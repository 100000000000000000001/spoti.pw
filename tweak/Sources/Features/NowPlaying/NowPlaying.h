// Now Playing: the glass bar (NowPlayingBar.x), the full screen player (Player.x) and the lyrics
// card with the page it expands into (Lyrics.x). The bar, the backdrop and the lyrics card are off
// until asked for, together through Redesigned UI in Appearance; the header buttons are on.
#import <UIKit/UIKit.h>

#define SGKeyNowPlayingBar @"spotifyglass.nowPlayingBar"
#define SGKeyPlayer @"spotifyglass.player"
#define SGKeyPlayerBackdrop @"spotifyglass.playerBackdrop"
#define SGKeyLyricsCard @"spotifyglass.lyricsCard"
#define SGHideBarConnect @"spotifyglass.hide.barConnect"   // the device button in the now playing bar

UIViewController *SGNowPlayingSettingsPage(void);   // the Player page

// Posted by NowPlayingBar.x as the full screen player starts to open or close, before the animation
// runs, and again once it is over; SGPlayerTransitionEnds says when it is expected to be over (as
// CACurrentMediaTime), 0 when none runs.
extern NSString *const SGPlayerTransitionNotification;
extern NSString *const SGPlayerTransitionEndedNotification;
CFTimeInterval SGPlayerTransitionEnds(void);
