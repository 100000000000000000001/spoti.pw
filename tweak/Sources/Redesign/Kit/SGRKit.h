// The Redesign Kit: what every redesigned screen (Redesign/<Screen>/) builds on, so the screens share
// one look and nothing is hand-rolled per screen. A screen imports this and Core/SGCore.h.
//
//     SGRedesign.h   Redesigned UI, the one switch, and the flags the redesigned screens force
//     SGRTokens.h    colours, type, spacing, radii, motion, the accessibility settings
//     SGRPalette.h   the artwork's edge colour, the field colour and the pre-blurred bitmaps
//     SGRField.h     the artwork field behind a page
//     SGRGlass.h     glass inside Spotify's round controls
//     SGRGlyph.h     bare glyph overlays and glyph buttons
//     SGRRestyle.h   keeping Spotify's views restyled: suppress, digits, lookups, shadows, firing controls
//     SGRBridges.h   player state, now playing artwork, links, the player's open and close
//
// A screen's hooks install only while Redesigned UI is on: every .x of a screen ends with
//     %ctor { if (!SGRedesignOn(@"<screen>")) return; %init; SGRequireClasses(@[...]); }
// and the legacy hooks of that screen stand aside with the same test, so with the switch off the mod
// behaves exactly as it did before the Kit.
#import "SGRedesign.h"
#import "SGRTokens.h"
#import "SGRPalette.h"
#import "SGRField.h"
#import "SGRGlass.h"
#import "SGRGlyph.h"
#import "SGRRestyle.h"
#import "SGRBridges.h"
