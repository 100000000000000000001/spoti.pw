#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Home.h"
#import "Features/Declutter/Declutter.h"
#import "Features/Playlist/Playlist.h"

static SGModRow *choiceRow(NSString *title, NSString *subtitle, SGHomeChoice choice) {
    return SGChoiceRow(title, subtitle, SGHomeChoiceKey(choice), SGHomeChoiceNames(choice),
                       SGHomeChoiceDefault(choice));
}

UIViewController *SGHomeGradientPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Gradient"
                                      intro:@"A wash behind the top of Home, under the avatar and the pills, fading into the page by the second shelf. Turning it on or off applies after you restart Spotify; the colour, the strength and the height take effect straight away."
                                   sections:@[
        SGSection(@"Gradient", @[
            SGOptionRow(@"Show", @"Off leaves Home the way Spotify draws it", SGKeyHomeGradient),
            choiceRow(@"Colour", nil, SGHomeChoiceTint),
            choiceRow(@"Strength", @"How much of that colour reaches the top of the screen", SGHomeChoiceStrength),
            choiceRow(@"Height", @"How far down the page it reaches before the page takes over", SGHomeChoiceHeight),
        ]),
    ] footer:nil];
}

UIViewController *SGHomeSettingsPage(void) {
    // The row reads its own state out, so the section says which colour is set without being opened.
    SGModRow *gradient = SGPageRow(@"Gradient", ^UIViewController *{ return SGHomeGradientPage(); });
    gradient.value = ^NSString *{
        if (!SGFlag(SGKeyHomeGradient, NO)) return @"Off";
        return SGHomeChoiceNames(SGHomeChoiceTint)[(NSUInteger)SGHomeChoiceValue(SGHomeChoiceTint)];
    };

    SGModRow *djButton = SGKillRow(@"DJ button", @"ios-home-evopage-impl.idj_show_dj_button");
    djButton.subtitle = @"The DJ button on Home";
    SGModRow *djBadge = SGKillRow(@"DJ beta badge", @"ios-home-evopage-impl.dj_mdc_beta_badge_enabled");
    djBadge.subtitle = @"The beta badge on the DJ";

    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithArray:@[
        SGSection(@"Home", @[
            SGWithSymbol(gradient, @"rectangle.tophalf.inset.filled"),
            SGFlagRow(@"Pull to refresh", @"ios-home-evopage-impl.pull_to_refresh_enabled"),
            SGFlagRow(@"Hide items from Shortcuts", @"ios-system-home-hidefromhome.is_hide_from_shortcuts_enabled"),
            SGFlagRow(@"Hide items from Recents", @"ios-system-home-hidefromhome.is_hide_from_recents_enabled"),
        ]),
        SGSection(@"Hide on Home", @[
            SGHideRow(@"Filter pills", @"Music and Podcasts next to your avatar", SGHideHomePills),
            SGHideRow(@"Shortcuts grid", @"The tiles at the top", SGHideHomeShortcuts),
            SGHideRow(@"Promo cards", @"Single cards such as the next episode of a podcast", SGHideHomePromo),
            SGHideRow(@"Preview cards", @"Album, playlist and video previews with a play button", SGHideHomePreviews),
            SGHideRow(@"DJ card", @"Your own personal DJ", SGHideHomeDJ),
            djButton,
            djBadge,
        ]),
    ]];
    [sections addObjectsFromArray:SGPlaylistSections()];
    [sections addObject:SGNotedSection(@"Library", @[
        SGFlagRow(@"Denser rows", @"ios-feature-yourlibaryx.denser_rows_enabled"),
        SGFlagRow(@"Sort playlists by recently updated", @"ios-feature-yourlibaryx.recently_updated_playlists_sort_enabled"),
        SGFlagRow(@"Sort artists by recently updated", @"ios-feature-yourlibaryx.recently_updated_artists_sort_enabled"),
        SGFlagRow(@"Recents", @"ios-feature-yourlibaryx.recents_enabled"),
        SGFlagRow(@"Recents sort order", @"ios-feature-yourlibaryx.recents_sort_order_enabled"),
        SGFlagRow(@"Library settings", @"ios-feature-yourlibaryx.library_settings_enabled"),
        SGFlagRow(@"Library Pro", @"ios-feature-yourlibaryx.your_library_pro_enabled"),
    ], @"Spotify's own Library options, some of them only rolled out to some accounts.")];
    return [[SGModPage alloc] initWithTitle:@"Home & Library" intro:@"Changes apply after you restart Spotify. The gradient's colour, strength and height apply straight away." sections:sections footer:nil];
}
