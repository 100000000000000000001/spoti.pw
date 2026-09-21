// The Lyrics page's parts. The page itself is App/Pages.m's, which adds what only one look has.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Lyrics.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"
#import "Shared/LyricsSources/LyricsSources.h"

SGModSection *SGLyricsSourcesSection(BOOL namingSource) {
    // The row reads the order out, so which sources are on is visible without opening it.
    SGModRow *sources = SGPageRow(@"Lyrics sources", ^UIViewController *{ return SGLyricsSourcesPage(); });
    sources.subtitle = @"BiniLyrics, Musixmatch, Unison, NetEase and LRCLIB, in the order you put them";
    sources.value = ^NSString *{
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (NSString *key in SGLyricsOrder()) [names addObject:SGLyricsProviderFor(key).name];
        return names.count ? [names componentsJoinedByString:@", "] : @"Off";
    };
    NSMutableArray<SGModRow *> *rows = [NSMutableArray arrayWithObjects:sources,
        SGOptionRow(@"Lyrics for every track", @"Offers the lyrics card on tracks Spotify has no lyrics for; needs a source above", SGKeyLyricsAllTracks), nil];
    if (namingSource) [rows addObject:SGOptionRow(@"Name the source", @"Reads out which source the lines on the full screen page came from", SGKeyLyricsCredit)];
    return SGNotedSection(@"Where lyrics come from", rows, @"With no source on, Spotify's own lyrics are left alone.");
}

SGModRow *SGLockScreenLyricsRow(void) {
    return SGOptionRow(@"Replace artist with lyrics", @"The line being sung shows in place of the artist, so lyrics show up on the lock screen and in CarPlay", SGKeyLockScreenLyrics);
}

SGModRow *SGLyricsTranslationLanguageRow(void) {
    return SGChoiceRow(@"Translation language", @"Of the translations the lyrics come with, the one to show; Any shows the first",
                       SGKeyLyricsTranslationLanguage, SGLyricsTranslationLanguageNames(), 0);
}

// Read by the redesign's lyrics view, the one place words are swept, so the page offers it there only.
SGModSection *SGLyricsWordTimingSection(void) {
    SGModRow *row = SGOptionRow(@"Simulate word-by-word timing", @"Guesses when each word of a line-synced line is sung, and sweeps it as if the source had timed it", SGKeyLyricsSimulateWords);
    return SGNotedSection(@"Word timing", @[row],
        @"Off, lyrics synced by the line light up a line at a time, and lyrics with no timing show as plain text. Word-synced lyrics sweep word by word either way.");
}
