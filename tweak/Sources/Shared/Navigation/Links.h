// Opening a spotify: URI the way the app opens a link of its own, through its link dispatcher: the
// tabs of the mod's own on either look's bar, the redesigned player's lyrics glyph.
#import <Foundation/Foundation.h>

// NO before the dispatcher is set up, or for a nil URI.
BOOL SGOpenSpotifyURI(NSURL *uri);
id SGLinkDispatcher(void);   // SPTLinkDispatcherImplementation, nil until it is set up
