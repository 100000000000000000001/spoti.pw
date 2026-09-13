#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Appearance.h"
#import "Features/Navbar/Navbar.h"
#import "Features/Flags/Flags.h"
#import "Features/NowPlaying/NowPlaying.h"

void SGSetLiquidGlassUI(BOOL on) {
    for (NSString *key in @[SGKeySpotifyGlass, SGKeySearchField, SGKeyNowPlayingBar, SGKeyPlayer, SGKeyPlayerBackdrop, SGKeyLyricsCard]) {
        SGSetEnabled(key, on);
    }
}

UIViewController *SGAppearanceSettingsPage(void) {
    SGModRow *tabBar = SGUnstableRow(@"Tab bar", @"[WIP] Unstable", SGKeyTabBar,
                        @"The glass capsule does not render the way iOS draws its own, and there is no selection indicator behind the active tab. Switching this on will look wrong.\n\nIf you want to take it further, pull requests are very welcome.");
    tabBar.defaultOn = NO;
    SGModRow *glass = SGOptionRow(@"Liquid Glass UI", @"Spotify's own glass navigation bar, slider and sheets, and with it the search field, now playing bar, artwork background and lyrics", SGKeySpotifyGlass);
    glass.changed = ^(BOOL on) { SGSetLiquidGlassUI(on); };
    return [[SGModPage alloc] initWithTitle:@"Appearance" intro:SGRestartNote sections:@[
        SGSection(nil, @[
            SGPageRow(@"Navbar", ^UIViewController *{ return SGNavbarSettingsPage(); }),
        ]),
        SGSection(@"Liquid Glass", @[
            tabBar,
            SGOptionRow(@"Search field", @"Glass capsule instead of the white field", SGKeySearchField),
            glass,
        ]),
        SGSection(@"Theme", @[
            SGOptionRow(@"AMOLED background", @"Pure black instead of Spotify's dark grey", SGKeyAmoled),
            SGStatActionRow(@"Accent colour", @"In place of Spotify's green, everywhere it is drawn; tap to pick", ^NSString *{ return SGAccentLabel(); }, ^{ SGPickAccent(); }),
            SGActionRow(@"Spotify's green", @"Back to the colour the app came with", ^{ SGSetInt(SGKeyAccent, -1); }),
        ]),
    ] footer:nil];
}
