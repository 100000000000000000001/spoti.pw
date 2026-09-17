// Redesign: per screen, either Spotify's own layout with the legacy tweaks on it, or the screen
// redesigned from the Kit (Redesign/<Screen>/). One switch per screen, off until asked for and read
// once per launch like every other switch, so a screen never changes hands while it is on screen.
// While a screen's switch is on, the legacy hooks of that screen stand aside (each gates itself with
// SGRedesignOn) and the redesign may force some of Spotify's remote-config flags, which the flag
// rows elsewhere then show locked, the way Liquid Glass UI locks the flags it owns.
//
// Threading: SGRedesignOn, SGRedesignAnyOn and SGRedesignForcedFlag are safe from any thread (the
// configuration provider asks from several). Registration happens in a %ctor, before Spotify reads a
// flag.
#import <UIKit/UIKit.h>

// spotifyglass.redesign.<screen>; the screens with a redesign are listed in SGRedesign.m.
#define SGKeyRedesignPrefix @"spotifyglass.redesign."
#define SGKeyRedesignPlayer @"spotifyglass.redesign.player"

// Whether the screen ("player") was redesigned when Spotify started. A screen without a
// redesign yet reads off whatever is stored for it.
BOOL SGRedesignOn(NSString *screen);
BOOL SGRedesignAnyOn(void);
// The screens with a redesign.
NSArray<NSString *> *SGRedesignScreens(void);

// The flags a screen's redesign forces, flag key to @YES/@NO/number/string, registered from the
// screen's %ctor whether or not the screen is on: the settings rows need the list to lock theirs.
// Only the screens on at launch force anything; an override from the All flags page still wins.
void SGRedesignForceFlags(NSString *screen, NSDictionary<NSString *, id> *flags);
// For Features/Flags/Flags.x, right after SGFlagOverride: the value a screen on at launch forces, or nil.
id SGRedesignForcedFlag(NSString *key);
// For the flag rows of Settings/SGModPage.m: the value a screen whose switch is on now forces, or
// nil. It follows the stored switch rather than the launch, as the Liquid Glass UI lock does.
id SGRedesignOwnedFlag(NSString *key);
