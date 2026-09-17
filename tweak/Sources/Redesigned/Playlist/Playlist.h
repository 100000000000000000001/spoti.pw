// The playlist redesign: Spotify's playlist page kept, with its controllers, its header and its list, and
// laid out the way the Music app lays a playlist out. Liked Songs and a playlist of the user's own are the
// same page (trees/clean/liked-songs/01.txt, own-playlist/01.txt: one FTPViewController, one
// SPTFreeTierPlaylistEncoreHeaderViewController), so one redesign covers all three. Album and artist pages
// are built by another framework and are left alone.
//
//     PlaylistField.x   the artwork field behind the whole page, the artwork it is read from, the flags
//                       the screen forces
//     PlaylistHeader.x  the header: the cover full bleed at the top dissolving into the field, the title,
//                       the creator and the length centred under it, and one row of glass controls --
//                       shuffle, a prominent Play capsule, add, and more where Spotify still has it
//     PlaylistRows.x    the track rows on the field with no surface of their own, rounded artwork, a
//                       hairline between them, and the curation pills collapsed
//
// Every hook installs only while Redesigned UI is on (SGRedesignedUI); the native look's do not then.
// Threading: main thread only.
#import <UIKit/UIKit.h>

// The page's list (trees/clean/playlist/02.txt:23).
extern NSString *const SGRPlaylistListIdentifier;

// The playlist page `view` is on, or nil: SPTFreeTierPlaylistEncoreHeaderViewController's own view, the one
// the tree names PL.Header, for anything under the header, and FTPViewController's view for the list.
UIViewController *SGRPlaylistHeaderOf(UIView *view);

// PlaylistField.x. The field belongs to the page `view` is on, found by walking up from it, so two playlist
// pages on the navigation stack keep a field each.
//
// The colour the page's field is showing, SGRNeutralField() before one has been read: what the header's
// cover has to dissolve into for there to be no seam.
UIColor *SGRPlaylistFieldColor(UIView *view);
// The cover of the page `view` is on, for its field to take its colour from. The same image again is a no-op.
void SGRPlaylistSetArtwork(UIView *view, UIImage *image);
