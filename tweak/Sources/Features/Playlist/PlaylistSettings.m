#import "Settings/SGModPage.h"
#import "Playlist.h"

NSArray<SGModSection *> *SGPlaylistSections(void) {
    return @[
        SGSection(@"Hide in the playlist header", @[
            SGHideRow(@"Cover artwork", @"The square cover over the title", SGHidePlaylistArtwork),
            SGHideRow(@"Description", @"The text under the title", SGHidePlaylistDescription),
            SGHideRow(@"Creator and collaborators", @"The faces, the name and Message", SGHidePlaylistCreator),
            SGHideRow(@"Length and saves", @"The line under the creator", SGHidePlaylistLength),
        ]),
        SGSection(@"Hide playlist buttons", @[
            SGHideRow(@"Video", @"The stack of clips at the start of the row", SGHidePlaylistVideo),
            SGHideRow(@"Add to library", @"The plus", SGHidePlaylistAddTo),
            SGHideRow(@"Download", @"The download arrow", SGHidePlaylistDownload),
            SGHideRow(@"Share", @"The button that opens the share sheet", SGHidePlaylistShare),
            SGHideRow(@"More", @"The three dots at the end of the row", SGHidePlaylistMore),
        ]),
        SGSection(@"Hide above the tracks", @[
            SGHideRow(@"Curation pills", @"Add, Mix, Video, Edit, Sort and the rest", SGHidePlaylistPills),
            SGHideRow(@"Find and sort bar", @"Find on page and Sort, under the header", SGHidePlaylistFind),
        ]),
    ];
}
