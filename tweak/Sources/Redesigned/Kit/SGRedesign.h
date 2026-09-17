// Redesign: Redesigned UI, one switch in Appearance, puts every redesigned screen (Redesign/<Screen>/)
// in place of Spotify's own and turns on Spotify's glass and the mod's glass switches (Appearance/AppearanceSettings.m).
// Off until asked for and read once per launch like every other switch, so a screen never changes
// hands while it is on screen. While it is on, the legacy hooks of the redesigned screens stand aside
// (each gates itself with SGRedesignOn), their switches are put away on their pages, and the
// redesign forces the remote-config flags it is built on, over any override, with their rows locked.
//
// Threading: SGRedesignOn, SGRedesignAnyOn and SGRedesignForcedFlag are safe from any thread (the
// configuration provider asks from several). Registration happens in a %ctor, before Spotify reads a
// flag.
#import <UIKit/UIKit.h>

#define SGKeyRedesign @"spotifyglass.redesign"

// Whether the screen ("player") is one Redesigned UI replaces and the switch was on when Spotify started.
BOOL SGRedesignOn(NSString *screen);
BOOL SGRedesignAnyOn(void);
// The screens Redesigned UI replaces.
NSArray<NSString *> *SGRedesignScreens(void);

// The flags a screen's redesign forces, flag key to @YES/@NO/number/string, registered from the
// screen's %ctor whether or not the screen is on: the settings rows need the list to lock theirs.
// Only while Redesigned UI was on at launch does anything get forced, and then over an override from
// the All flags page too: the redesign is built on these values.
void SGRedesignForceFlags(NSString *screen, NSDictionary<NSString *, id> *flags);
// For Features/Flags/Flags.x, before SGFlagOverride: the value a screen on at launch forces, or nil.
id SGRedesignForcedFlag(NSString *key);
// For the flag rows of Settings/SGModPage.m: the value a redesigned screen forces while the stored
// switch is on, or nil. It follows the stored switch rather than the launch, as the glass lock does.
id SGRedesignOwnedFlag(NSString *key);
