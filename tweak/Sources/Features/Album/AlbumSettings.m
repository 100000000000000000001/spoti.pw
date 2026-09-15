#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Album.h"

UIViewController *SGAlbumSettingsPage(void) {
    NSArray<SGModSection *> *sections = @[
        SGSection(@"Header", @[
            SGOptionRow(@"Artwork background", nil, SGKeyAlbumBackdrop),
        ]),
        SGSection(@"Hide in the header", @[
            SGHideRow(@"Explore (video deck)", nil, SGHideAlbumExplore),
            SGHideRow(@"Add to library", nil, SGHideAlbumAddTo),
            SGHideRow(@"Download", nil, SGHideAlbumDownload),
            SGHideRow(@"More options", nil, SGHideAlbumMore),
        ]),
        SGNotedSection(@"Hide on the page", @[
            SGHideRow(@"More by the artist", nil, SGHideAlbumMoreBy),
            SGHideRow(@"Related music videos", nil, SGHideAlbumVideos),
            SGHideRow(@"Concerts", nil, SGHideAlbumConcerts),
            SGHideRow(@"Merch", nil, SGHideAlbumMerch),
            SGHideRow(@"You might also like", nil, SGHideAlbumYouMightLike),
        ], @"Sections are found by their English titles, so these do nothing while Spotify is in another language."),
    ];
    return [[SGModPage alloc] initWithTitle:@"Album" intro:nil sections:sections footer:nil];
}
