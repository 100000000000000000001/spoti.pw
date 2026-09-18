// Onboarding: a welcome page over Home the first time this build runs, in glass: what the mod is,
// where Mod Settings lives, and Redesigned UI, offered switched on. The look is picked at launch, so
// a changed switch ends the welcome in a restart. The Mod page offers it again.
#import <UIKit/UIKit.h>

#define SGKeyOnboardingSeen @"spotifyglass.onboarding.seen"

// Presents the tour over the top of the app; does nothing while it is already up.
void SGShowOnboarding(void);
BOOL SGOnboardingShowing(void);
