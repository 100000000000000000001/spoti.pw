// What the Lyrics page holds for either look: Apple Music style, the lock screen, where lyrics come from
// and Spotify's lyrics flags. The page itself is App/Pages.m's, which adds the native look's glass row.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Lyrics.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"
#import "Shared/LyricsSources/LyricsSources.h"

NSArray<SGModRow *> *SGLyricsLookRows(void) {
    return @[
        SGOptionRow(@"Apple Music style", @"Word by word on the full screen page; timing inside a line is estimated unless Musixmatch has it", SGKeyKaraokeLyrics),
        SGOptionRow(@"Lyrics on the lock screen", @"The line being sung in place of the artist, also in the Dynamic Island, Control Center and CarPlay", SGKeyLockScreenLyrics),
    ];
}

NSArray<SGModSection *> *SGLyricsSourceSections(void) {
    // The row reads the order out, so which sources are on is visible without opening it.
    SGModRow *sources = SGPageRow(@"Lyrics sources", ^UIViewController *{ return SGLyricsSourcesPage(); });
    sources.subtitle = @"BiniLyrics, Musixmatch, Unison, NetEase and LRCLIB, in the order you put them";
    sources.value = ^NSString *{
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (NSString *key in SGLyricsOrder()) [names addObject:SGLyricsProviderFor(key).name];
        return names.count ? [names componentsJoinedByString:@", "] : @"Off";
    };
    return @[
        SGNotedSection(@"Where lyrics come from", @[
            sources,
            SGOptionRow(@"Lyrics for every track", @"Offers the lyrics card on tracks Spotify has no lyrics for; needs a source above", SGKeyLyricsAllTracks),
            SGOptionRow(@"Name the source", @"Reads out which source the lines on the full screen page came from", SGKeyLyricsCredit),
        ], @"With no source on, Spotify's own lyrics are left alone."),
        SGSection(@"Spotify's flags", @[
            SGFlagRow(@"Translations in the player", @"ios-feature-lyrics.enable_lyrics_multilanguage_npv"),
            SGFlagRow(@"Translations full screen", @"ios-feature-lyrics.enable_lyrics_multilanguage_fullscreen"),
            SGFlagRow(@"Keep lyrics offline", @"ios-feature-lyrics.lyrics_offline_enabled"),
            SGFlagRow(@"Dynamic colours", @"ios-feature-lyrics.enable_dynamic_colors"),
            SGFlagRow(@"Centre a single line", @"ios-feature-lyrics.is_single_line_centering_enabled"),
            SGFlagRow(@"Full screen on track change", @"ios-feature-lyrics.enable_fullscreen_track_change"),
            SGFlagRow(@"Lyrics toggle in the context menu", @"ios-feature-lyrics.lyrics_context_menu_toggle_enabled"),
        ]),
    ];
}
