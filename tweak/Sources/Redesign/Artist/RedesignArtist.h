// The artist page redesigned (Mod Settings > Redesign > Artist): Spotify's own page and its Music list
// stay, for the data, the rows and every row interaction, while the chrome is the Kit's: one field
// colour behind the whole page, the hero with the photo dissolving into it, the glass Shuffle, Play and
// Follow firing Spotify's own controls, and the Kit's section headers. Everything on the list that is
// not music collapses, told apart by accessibility identifiers, so it works in any language.
//
//     ArtistPage.x   the page: finding it by its URI, the field, the hero in Spotify's header, the tabs
//     ArtistList.x   the Music list: which cells stay, the section headers, the rows restyled
//
// Trees: trees/clean/artist/01-07.txt (Shawn Mendes, with an artist pick and a release countdown) and
// 08-13.txt (The Weeknd, with a liked songs row), recorded stock on 9.1.78.
#import <UIKit/UIKit.h>

// Off until switched on: the row of this artist's songs in Liked Songs collapses with the rest.
#define SGKeyRedesignArtistHideLikedSongs @"spotifyglass.redesign.artist.hideLikedSongs"

// The state of one redesigned artist page, kept on its TemplateView.
@interface SGArtistPage : NSObject
@property (nonatomic, readonly, copy) NSString *uri;
@end

// The redesigned artist page `view` is on, found up its superviews. nil on any other page (an author's
// page shares the template and the creator-page identifier, so the URI decides), and nil with
// `pending` set while the page's URI cannot be read yet, so the caller asks again later.
SGArtistPage *SGArtistPageOf(UIView *view, BOOL *pending);
