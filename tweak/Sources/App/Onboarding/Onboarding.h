// Onboarding: a welcome tour over Home the first time this build runs, four pages of glass: what
// the mod is, the look switches, the ad switches, and where Mod Settings lives with the repo to
// star. The switches it sets are read at launch like every other, so a changed one ends the tour
// in a restart. The Mod page offers the tour again.
#import <UIKit/UIKit.h>

#define SGKeyOnboardingSeen @"spotifyglass.onboarding.seen"

// Presents the tour over the top of the app; does nothing while it is already up.
void SGShowOnboarding(void);
BOOL SGOnboardingShowing(void);
