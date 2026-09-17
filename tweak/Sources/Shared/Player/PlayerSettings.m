// The player's settings that do not depend on the look: the lock screen widget's flags.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "PlayerSettings.h"

// Flag rows show the flag's name as their subtitle by default.
static SGModRow *bare(SGModRow *row) {
    row.subtitle = nil;
    return row;
}

UIViewController *SGLockScreenWidgetPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Lock screen widget" intro:SGRestartNote sections:@[
        SGSection(@"Controls", @[
            bare(SGFlagRow(@"Like and dislike buttons", @"ios-feature-lockscreen.like_dislike_enabled")),
            bare(SGFlagRow(@"Skip button on podcasts", @"ios-feature-lockscreen.skip_button_on_podcasts")),
            bare(SGFlagRow(@"Chapter skip controls", @"ios-feature-lockscreen.enable_chapter_skip_controls")),
            bare(SGFlagRow(@"Burst skip", @"ios-feature-lockscreen.burst_skip_enabled")),
        ]),
        SGSection(@"Artwork", @[
            bare(SGFlagRow(@"Animated artwork", @"ios-feature-lockscreen.animated_artwork_enabled")),
            bare(SGFlagRow(@"Video artwork", @"ios-feature-lockscreen.vit_artwork_enabled")),
            bare(SGFlagRow(@"Companion content", @"ios-feature-lockscreen.companion_content_enabled")),
        ]),
    ] footer:nil];
}
