#import "Settings/SGModPage.h"
#import "NowPlaying.h"
#import "Features/Declutter/Declutter.h"
#import "Features/Flags/Flags.h"
#import "Features/Gestures/Gestures.h"
#import "Features/ArtistBlock/ArtistBlock.h"

static UIViewController *lyricsPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Lyrics" intro:SGRestartNote sections:@[
        SGSection(@"Spotify's flags", @[
            SGFlagRow(@"Translations in the player", @"ios-feature-lyrics.enable_lyrics_multilanguage_npv"),
            SGFlagRow(@"Translations full screen", @"ios-feature-lyrics.enable_lyrics_multilanguage_fullscreen"),
            SGFlagRow(@"Keep lyrics offline", @"ios-feature-lyrics.lyrics_offline_enabled"),
            SGFlagRow(@"Lyrics toggle in the context menu", @"ios-feature-lyrics.lyrics_context_menu_toggle_enabled"),
            SGFlagRow(@"Dynamic colours", @"ios-feature-lyrics.enable_dynamic_colors"),
            SGFlagRow(@"Centre a single line", @"ios-feature-lyrics.is_single_line_centering_enabled"),
            SGFlagRow(@"Full screen on track change", @"ios-feature-lyrics.enable_fullscreen_track_change"),
        ]),
    ] footer:nil];
}

UIViewController *SGNowPlayingSettingsPage(void) {
    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithArray:@[
        SGSection(nil, @[
            SGPageRow(@"Gestures", ^UIViewController *{ return SGGesturesSettingsPage(); }),
            SGPageRow(@"Lyrics", ^UIViewController *{ return lyricsPage(); }),
            SGPageRow(@"Blocked artists", ^UIViewController *{ return SGArtistBlockSettingsPage(); }),
        ]),
        SGSection(@"Liquid Glass", @[
            SGOptionRow(@"Now playing bar", @"Glass card with round artwork", SGKeyNowPlayingBar),
            SGOptionRow(@"Artwork background", @"The cover blurred and dimmed behind the player instead of the flat album colour", SGKeyPlayerBackdrop),
            SGOptionRow(@"Header buttons", @"Glass circles behind close and more, over the artwork", SGKeyPlayer),
            SGOptionRow(@"Lyrics", @"Glass card, and the page it expands into", SGKeyLyricsCard),
        ]),
        SGSection(@"Spotify's flags", @[
            SGFlagRow(@"Sheet style player", @"ios-feature-nowplaying.sheet_style_npv"),
            SGFlagRow(@"Queue as a bottom sheet", @"ios-feature-nowplaying.bottom_sheet_queue_enabled"),
            SGFlagRow(@"Queue flip transition", @"ios-feature-nowplaying.queue_flip_transition_enabled"),
            SGFlagRow(@"Mini player transition animations", @"ios-feature-nowplaying.miniplayer_transition_animations"),
            SGFlagRow(@"Bar to cover art animation", @"ios-feature-nowplaying.bartocoverart_animation_enabled"),
            SGFlagRow(@"Expand the sticky header on tap", @"ios-feature-nowplaying.expand_sticky_header_on_tap"),
            SGFlagRow(@"Redesigned header with context menu", @"ios-feature-nowplaying.new_redesign_header_with_context_menu_enabled"),
            SGFlagRow(@"Video in the mini player", @"ios-feature-nowplaying.video_in_miniplayer"),
            SGKillRow(@"Disable Canvas", @"ios-feature-canvas.canvas_enabled"),
        ]),
        SGSection(@"Hide buttons", @[
            SGHideRow(@"Shuffle", @"Left of the playback controls", SGHideShuffle),
            SGHideRow(@"Repeat", @"Right of the playback controls", SGHideRepeat),
            SGHideRow(@"Connect to a device", @"The speaker and device name in the bottom row", SGHideConnect),
            SGHideRow(@"Share", @"The share button in the bottom row", SGHideShare),
            SGHideRow(@"Queue", @"The queue button in the bottom row", SGHideQueue),
            SGHideRow(@"Add to playlist", @"The plus next to the track title", SGHideAddTo),
        ]),
        SGSection(@"Under the artwork", @[
            SGHideRow(@"Lyrics preview", @"The lyric lines shown under the artwork", SGHideLyricsInline),
        ]),
        SGSection(@"Hide cards below the player", @[
            SGHideRow(@"Lyrics", @"The lyrics card", SGHideLyricsCard),
            SGHideRow(@"About the artist", @"Photo, listeners and biography", SGHideAboutArtist),
            SGHideRow(@"Related videos", @"The video carousel", SGHideRelatedVideos),
            SGHideRow(@"SongDNA", @"Discover the people behind the song", SGHideSongDNA),
            SGHideRow(@"Live events", @"Concerts and tickets", SGHideLiveEvents),
            SGHideRow(@"Explore the artist", @"The vertical video cards", SGHideExploreArtist),
            SGHideRow(@"Credits", @"Performers and writers", SGHideCredits),
            SGHideRow(@"Merch", @"The artist's shop", SGHideMerch),
            SGHideRow(@"Recommendations", @"\"Artist: what you might like\", the episode and track rows", SGHideRecommendations),
        ]),
    ]];
    [sections addObjectsFromArray:SGPlaybackSections()];
    [sections addObject:SGLockScreenSection()];
    return [[SGModPage alloc] initWithTitle:@"Player" intro:SGRestartNote sections:sections footer:nil];
}
