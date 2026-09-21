// The Now playing page of the redesign, under Player (App/Pages.m puts it there): the bar and the
// player behind it.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlayingBar.h"
#import "Redesigned/Player/Player.h"

UIViewController *SGRNowPlayingBarSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Now playing" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGHideRow(@"Hide the device button", @"The speaker icon on the now playing bar", SGRHideBarConnect),
        ]),
        SGNotedSection(nil, @[
            SGSwitchRow(@"Moving background", @"The artwork's colours drift slowly behind the player", SGRKeyPlayerMotion),
        ], @"Off, the blurred artwork stays still. The colours hold still anyway while a song is paused, with Reduce Motion and in Low Power Mode."),
    ] footer:nil];
}
