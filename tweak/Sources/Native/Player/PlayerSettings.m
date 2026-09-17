// The native player's settings: Spotify's own player screen and the parts of it to hide, and the queue
// and devices flags. The Player page that holds them is App/Pages.m's.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "NowPlaying.h"

// Flag rows show the flag's name as their subtitle by default.
static SGModRow *bare(SGModRow *row) {
    row.subtitle = nil;
    return row;
}

NSArray<SGModSection *> *SGNativePlayerScreenSections(void) {
    return @[
        SGSection(@"Player screen", @[
            SGOptionRow(@"Artwork background", @"The cover blurred and dimmed behind the player instead of the flat album colour", SGKeyPlayerBackdrop),
            SGOptionRow(@"Glass header buttons", nil, SGKeyPlayer),
            bare(SGKillRow(@"Disable Canvas", @"ios-feature-canvas.canvas_enabled")),
            bare(SGFlagRow(@"Sheet style player", @"ios-feature-nowplaying.sheet_style_npv")),
            bare(SGFlagRow(@"Redesigned header", @"ios-feature-nowplaying.new_redesign_header_with_context_menu_enabled")),
            bare(SGFlagRow(@"New progress slider", @"ios-feature-encoreexperiments.new_npv_slider_enabled")),
            bare(SGFlagRow(@"Expand the sticky header on tap", @"ios-feature-nowplaying.expand_sticky_header_on_tap")),
        ]),
        SGSection(@"Hide cards below the player", @[
            SGHideRow(@"Lyrics", nil, SGHideLyricsCard),
            SGHideRow(@"About the artist", nil, SGHideAboutArtist),
            SGHideRow(@"Related videos", nil, SGHideRelatedVideos),
            SGHideRow(@"SongDNA", nil, SGHideSongDNA),
            SGHideRow(@"Live events", nil, SGHideLiveEvents),
            SGHideRow(@"Explore the artist", nil, SGHideExploreArtist),
            SGHideRow(@"Credits", nil, SGHideCredits),
            SGHideRow(@"Merch", nil, SGHideMerch),
            SGHideRow(@"Recommendations", nil, SGHideRecommendations),
        ]),
        SGSection(@"Hide on the player", @[
            SGHideRow(@"Lyrics preview", @"The lyric lines shown under the artwork", SGHideLyricsInline),
            SGHideRow(@"Shuffle", nil, SGHideShuffle),
            SGHideRow(@"Repeat", nil, SGHideRepeat),
            SGHideRow(@"Add to playlist", nil, SGHideAddTo),
            SGHideRow(@"Queue", nil, SGHideQueue),
            SGHideRow(@"Share", nil, SGHideShare),
            SGHideRow(@"Connect to a device", nil, SGHideConnect),
        ]),
    ];
}

SGModRow *SGGlassLyricsRow(void) {
    return SGOptionRow(@"Glass lyrics", @"Glass card, and the page it expands into", SGKeyLyricsCard);
}

UIViewController *SGQueueSettingsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Queue & devices" intro:SGRestartNote sections:@[
        SGSection(@"Bottom sheets", @[
            bare(SGFlagRow(@"Queue as a bottom sheet", @"ios-feature-nowplaying.bottom_sheet_queue_enabled")),
            bare(SGFlagRow(@"Connect as a bottom sheet", @"ios-feature-nowplaying-elements.enable_connect_bottom_sheet")),
            bare(SGFlagRow(@"Connect sheet from the video switcher", @"ios-playbackcontrol-audiovideoswitcher-impl.enable_connect_bottom_sheet")),
        ]),
        SGSection(@"Queue", @[
            bare(SGFlagRow(@"Queue flip transition", @"ios-feature-nowplaying.queue_flip_transition_enabled")),
            bare(SGFlagRow(@"Play next in the context menu", @"ios-feature-queue.is_play_next_context_menu_enabled")),
        ]),
    ] footer:nil];
}
