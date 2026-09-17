// The Redesign Kit: what every part of the redesign (Redesigned/<Part>/) builds on, so the screens share
// one look and nothing is hand-rolled per screen. A screen imports this and Core/SGCore.h.
//
//     SGRedesign.h   Redesigned UI, the one switch, and the flags the redesigned screens force
//     SGRTokens.h    colours, type, spacing, radii, motion, the accessibility settings
//     SGRPalette.h   the artwork's edge colour, the field colour and the pre-blurred bitmaps
//     SGRField.h     the artwork field behind a page
//     SGRGlass.h     glass inside Spotify's round controls
//     SGRGlyph.h     bare glyph overlays and glyph buttons
//     SGRRestyle.h   keeping Spotify's views restyled: suppress, digits, lookups, shadows, firing controls
//     SGRBridges.h   player state, now playing artwork, the player's open and close
//     SGRRepaint.h   the areas the redesign keeps transparent when Spotify repaints them
//
// Every hook file of the redesign starts its %ctor with `if (!SGRedesignedUI()) return;` and every one
// of Native/ with `if (!SGNativeUI()) return;` (Core/SGUIMode.h), so the two looks never run together.
#import "SGRedesign.h"
#import "SGRTokens.h"
#import "SGRPalette.h"
#import "SGRField.h"
#import "SGRGlass.h"
#import "SGRGlyph.h"
#import "SGRRestyle.h"
#import "SGRBridges.h"
#import "SGRRepaint.h"
