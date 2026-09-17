#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Redesign/Kit/SGRedesign.h"
#import "Artist.h"

UIViewController *SGArtistSettingsPage(void) {
    NSArray<SGModSection *> *sections = @[
        SGSection(@"Photo", @[
            SGOptionRow(@"Fade into a blur", @"The photo melts into a blurred copy of itself instead of ending in a straight line", SGKeyArtistPhotoFade),
        ]),
        SGSection(@"Hide in the header", @[
            SGHideRow(@"Explore (video deck)", nil, SGHideArtistExplore),
            SGHideRow(@"Follow", nil, SGHideArtistFollow),
            SGHideRow(@"More options", nil, SGHideArtistMore),
            SGHideRow(@"Shuffle", nil, SGHideArtistShuffle),
            SGHideRow(@"Verified badge", nil, SGHideArtistVerified),
            SGHideRow(@"Monthly listeners", nil, SGHideArtistListeners),
        ]),
        SGNotedSection(@"Tabs", @[
            SGHideRow(@"Hide the tab bar", nil, SGHideArtistTabBar),
        ], @"Music, Video, Merch, Events and any other tab. The page stays on Music and no longer swipes to the others."),
        SGNotedSection(@"Hide on the page", @[
            SGHideRow(@"Songs you liked", nil, SGHideArtistLikedSongs),
            SGHideRow(@"Popular", nil, SGHideArtistPopular),
            SGHideRow(@"Artist pick", nil, SGHideArtistPick),
            SGHideRow(@"Popular releases", nil, SGHideArtistReleases),
            SGHideRow(@"Featuring", nil, SGHideArtistFeaturing),
            SGHideRow(@"Music videos", nil, SGHideArtistVideos),
            SGHideRow(@"About", nil, SGHideArtistAbout),
            SGHideRow(@"Artist playlists", nil, SGHideArtistPlaylists),
            SGHideRow(@"Fans also like", nil, SGHideArtistFansAlsoLike),
            SGHideRow(@"Appears on", nil, SGHideArtistAppearsOn),
            SGHideRow(@"Discovered on", nil, SGHideArtistDiscoveredOn),
        ], @"Sections are found by their English titles, so these do nothing while Spotify is in another language."),
        SGSection(@"Spotify's own", @[
            SGFlagRow(@"Share button in the header", @"ios-creator-impl.share_in_action_row_enabled_artist"),
            SGFlagRow(@"More options in the navigation bar", @"ios-creator-impl.context_menu_in_navigation_bar_enabled_artist"),
            SGFlagRow(@"Top collaborators", @"ios-creator-impl.is_top_collaborators_enabled"),
            SGFlagRow(@"Artist facts", @"ios-creator-impl.is_artist_facts_enabled"),        ]),
    ];
    // While the redesign has the page, these switches stand aside; the note says so and opens its page.
    SGModSection *note = SGRedesignNoteSection(@"artist");
    if (note) sections = [@[note] arrayByAddingObjectsFromArray:sections];
    return [[SGModPage alloc] initWithTitle:@"Artist" intro:nil sections:sections footer:nil];
}
