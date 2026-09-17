// The Redesign Kit: what every redesigned screen (Redesign/<Screen>/) builds on, so the screens share
// one look and nothing is hand-rolled per screen. A screen imports this and Core/SGCore.h.
//
//     SGRedesign.h   the switch per screen, the flags a screen forces, the Redesign page
//     SGRTokens.h    colours, type, spacing, radii, motion, the accessibility settings
//     SGRPalette.h   the artwork's edge colour, the field colour and the pre-blurred bitmaps
//     SGRField.h     the artwork field behind a page, and content cards on it
//     SGRHero.h      the full-width hero header with title, meta and the action slot
//     SGRGlass.h     glass behind Spotify's controls, glass buttons, the action row
//     SGRGlyph.h     bare glyph overlays and glyph buttons
//     SGRRestyle.h   keeping Spotify's views restyled: suppress, digits, lookups, cells, repaint roots
//     SGRBridges.h   player state, now playing artwork, links, the player's open and close
//
// A screen's hooks install only while its switch is on: every .x of a screen ends with
//     %ctor { if (!SGRedesignOn(@"<screen>")) return; %init; SGRequireClasses(@[...]); }
// and the legacy hooks of that screen stand aside with the same test, so with every switch off the mod
// behaves exactly as it did before the Kit.
#import "SGRedesign.h"
#import "SGRTokens.h"
#import "SGRPalette.h"
#import "SGRField.h"
#import "SGRHero.h"
#import "SGRGlass.h"
#import "SGRGlyph.h"
#import "SGRRestyle.h"
#import "SGRBridges.h"
