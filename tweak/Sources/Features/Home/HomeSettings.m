#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Home.h"
#import "Features/Declutter/Declutter.h"
#import "Features/Playlist/Playlist.h"
#import "Features/Artist/Artist.h"
#import "Features/Album/Album.h"

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

static UIViewController *libraryPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Library" intro:nil sections:@[
        SGNotedSection(@"Library", @[
            SGFlagRow(@"Denser rows", @"ios-feature-yourlibaryx.denser_rows_enabled"),
            SGFlagRow(@"Sort playlists by recently updated", @"ios-feature-yourlibaryx.recently_updated_playlists_sort_enabled"),
            SGFlagRow(@"Sort artists by recently updated", @"ios-feature-yourlibaryx.recently_updated_artists_sort_enabled"),
            SGFlagRow(@"Recents", @"ios-feature-yourlibaryx.recents_enabled"),
            SGFlagRow(@"Recents sort order", @"ios-feature-yourlibaryx.recents_sort_order_enabled"),
            SGFlagRow(@"Library settings", @"ios-feature-yourlibaryx.library_settings_enabled"),
            SGFlagRow(@"Library Pro", @"ios-feature-yourlibaryx.your_library_pro_enabled"),
        ], @"Spotify's own Library options, some of them only rolled out to some accounts."),
    ] footer:nil];
}

// Flag rows show the flag's name as their subtitle by default.
static SGModRow *bare(SGModRow *row) {
    row.subtitle = nil;
    return row;
}

UIViewController *SGHomeSettingsPage(void) {
    // The row reads its own state out, so the section says which colour is set without being opened.
    SGModRow *gradient = SGPageRow(@"Gradient", ^UIViewController *{ return SGHomeGradientPage(); });
    gradient.value = ^NSString *{
        if (!SGFlag(SGKeyHomeGradient, NO)) return @"Off";
        return SGHomeChoiceNames(SGHomeChoiceTint)[(NSUInteger)SGHomeChoiceValue(SGHomeChoiceTint)];
    };

    NSArray<SGModSection *> *sections = @[
        SGSection(nil, @[
            SGWithSymbol(SGPageRow(@"Playlists", ^UIViewController *{ return SGPlaylistSettingsPage(); }), @"music.note.list"),
            SGWithSymbol(SGPageRow(@"Library", ^UIViewController *{ return libraryPage(); }), @"books.vertical"),
            SGWithSymbol(SGPageRow(@"Album", ^UIViewController *{ return SGAlbumSettingsPage(); }), @"square.stack"),
            SGWithSymbol(SGPageRow(@"Artist", ^UIViewController *{ return SGArtistSettingsPage(); }), @"music.mic"),
        ]),
        SGSection(@"Home", @[
            SGWithSymbol(gradient, @"rectangle.tophalf.inset.filled"),
            bare(SGFlagRow(@"Pull to refresh", @"ios-home-evopage-impl.pull_to_refresh_enabled")),
        ]),
        SGSection(@"Hide on Home", @[
            SGHideRow(@"Filter pills", nil, SGHideHomePills),
            SGHideRow(@"Shortcuts grid", nil, SGHideHomeShortcuts),
            SGHideRow(@"Promo cards", nil, SGHideHomePromo),
            SGHideRow(@"Preview cards", nil, SGHideHomePreviews),
            SGHideRow(@"DJ card", nil, SGHideHomeDJ),
            bare(SGKillRow(@"DJ button", @"ios-home-evopage-impl.idj_show_dj_button")),
            bare(SGKillRow(@"DJ beta badge", @"ios-home-evopage-impl.dj_mdc_beta_badge_enabled")),
        ]),
    ];
    return [[SGModPage alloc] initWithTitle:@"Home & Library" intro:nil sections:sections footer:nil];
}
