// The redesign's now playing bar: the glass card it becomes (NowPlayingBar.x), Spotify's device button
// on that card hidden on request (BarConnect.x), and the bar's page in Mod Settings
// (NowPlayingBarSettings.m). The redesign keeps its own copy of the hide switch and its own key; the
// native look's lives in Native/NowPlayingBar/.
#import <UIKit/UIKit.h>

#define SGRHideBarConnect @"spotifyglass.redesign.hide.barConnect"   // the device button on the card

UIViewController *SGRNowPlayingBarSettingsPage(void);
