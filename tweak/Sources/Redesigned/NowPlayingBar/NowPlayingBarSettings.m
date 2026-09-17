// The Now playing page of the redesign, under Player (App/Pages.m puts it there).
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlayingBar.h"

UIViewController *SGRNowPlayingBarSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Now playing" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGHideRow(@"Hide the device button", @"The speaker icon on the now playing bar", SGRHideBarConnect),
        ]),
    ] footer:nil];
}
