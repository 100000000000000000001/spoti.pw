#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Pages.h"
#import "Shared/ArtistBlock/ArtistBlock.h"
#import "Shared/Gestures/Gestures.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/Player/PlayerSettings.h"
#import "Native/Appearance/Appearance.h"
#import "Native/Navbar/Navbar.h"
#import "Native/NowPlayingBar/NowPlayingBar.h"
#import "Native/Player/NowPlaying.h"
#import "Redesigned/Navbar/Navbar.h"

NSString *const SGRedesignedUIInfo = @"Replaces Spotify's own look with the mod's redesign, built in Liquid Glass: the glass tab bar, search field and now playing bar, the full screen player with the lyrics under it, Spotify's own glass bars and sheets, and every screen redesigned later.\n\nThe redesign starts from a clean sheet: the switches that change Spotify's own screens (the player, Home, playlists, albums, artists, AMOLED and the accent colour) are put away while it is on, and none of them runs. What works the same with either look stays: ads and privacy, lyrics sources, gestures, blocked artists.\n\nChanges apply after you restart Spotify.";

void SGSetRedesignedUI(BOOL on) {
    SGSetEnabled(SGKeyRedesign, on);
}

SGModSection *SGAppearanceSection(void) {
    SGModRow *redesign = SGOptionRow(@"Redesigned UI", @"The mod's own look in Liquid Glass, from a clean sheet", SGKeyRedesign);
    redesign.glows = YES;
    redesign.info = SGRedesignedUIInfo;
    redesign.changed = ^(BOOL on) { SGSetRedesignedUI(on); };
    NSMutableArray<SGModRow *> *rows = [NSMutableArray arrayWithObject:SGWithSymbol(redesign, @"sparkles")];
    if (!SGRedesignedUIStored()) [rows addObjectsFromArray:SGNativeAppearanceRows()];
    return SGNotedSection(@"Appearance", rows, @"Changes apply after you restart Spotify.");
}

UIViewController *SGNavbarPage(void) {
    return SGRedesignedUIStored() ? SGRNavbarSettingsPage() : SGNavbarSettingsPage();
}

static UIViewController *lyricsPage(void) {
    NSMutableArray<SGModRow *> *look = [SGLyricsLookRows() mutableCopy];
    if (!SGRedesignedUIStored()) [look insertObject:SGGlassLyricsRow() atIndex:1];
    NSArray<SGModSection *> *sections = [@[SGSection(nil, look)] arrayByAddingObjectsFromArray:SGLyricsSourceSections()];
    return [[SGModPage alloc] initWithTitle:@"Lyrics" intro:SGRestartNote sections:sections footer:nil];
}

UIViewController *SGPlayerSettingsPage(void) {
    SGModRow *blocked = SGPageRow(@"Blocked artists", ^UIViewController *{ return SGArtistBlockSettingsPage(); });
    blocked.value = ^NSString *{
        return SGFlag(SGKeyArtistBlock, NO) ? @(SGBlockedArtists().count).stringValue : @"Off";
    };
    BOOL native = !SGRedesignedUIStored();

    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithObject:SGSection(nil, @[
        SGWithSymbol(SGPageRow(@"Gestures", ^UIViewController *{ return SGGesturesSettingsPage(); }), @"hand.tap"),
        SGWithSymbol(SGPageRow(@"Lyrics", ^UIViewController *{ return lyricsPage(); }), @"quote.bubble"),
        SGWithSymbol(blocked, @"person.crop.circle.badge.xmark"),
    ])];
    NSMutableArray<SGModRow *> *pages = [NSMutableArray array];
    if (native) {
        [pages addObject:SGWithSymbol(SGPageRow(@"Now playing bar", ^UIViewController *{ return SGNowPlayingBarSettingsPage(); }), @"rectangle.bottomthird.inset.filled")];
        [pages addObject:SGWithSymbol(SGPageRow(@"Queue & devices", ^UIViewController *{ return SGQueueSettingsPage(); }), @"text.line.first.and.arrowtriangle.forward")];
    }
    [pages addObject:SGWithSymbol(SGPageRow(@"Lock screen widget", ^UIViewController *{ return SGLockScreenWidgetPage(); }), @"lock")];
    [sections addObject:SGSection(nil, pages)];
    if (native) [sections addObjectsFromArray:SGNativePlayerScreenSections()];

    return [[SGModPage alloc] initWithTitle:@"Player"
                                      intro:@"Changes apply after you restart Spotify. Gestures and Blocked artists apply straight away."
                                   sections:sections
                                     footer:nil];
}
