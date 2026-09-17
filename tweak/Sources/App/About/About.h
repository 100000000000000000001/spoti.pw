// About: where the build points its user, and whether the site has a newer one (Update.m). The
// status is a string for the Updates row; the page's ticker reads it, so the check needs no
// callback. SGCheckForUpdate(NO) respects a six hour cache, SGCheckForUpdate(YES) always asks.
#import <UIKit/UIKit.h>
#import "Settings/SGModPage.h"

extern NSString *const SGUpdateURL;   // the site and the repo are in Settings/SGPageStyle.h
NSString *SGUpdateVersion(void);  // nil unless the site has one newer than this build
NSString *SGUpdateNotes(void);
NSString *SGUpdateStatus(void);
void SGCheckForUpdate(BOOL force);


// Whether the now playing card on the lock screen can open this build. It depends on the signature,
// not on the mod: iOS launches by the App ID of the application-identifier entitlement, so a build
// whose bundle id is not that App ID cannot be opened from the card. Signing.m says so once.
extern NSString *const SGSigningHelpURL;
NSString *SGSigningAppIdentifier(void);      // App ID without the team prefix, nil if unreadable
BOOL SGSigningOpensFromLockScreen(void);     // YES when unreadable, so a build that works stays quiet
SGModRow *SGSigningWarningRow(void);          // nil while the signature is sound
void SGCheckSigningOnce(void);
void SGShowSigningFixIfPending(void);   // the sheet the tour held back, if any

// Backup.m: the settings out to a JSON file through the share sheet, and back in from one, replacing
// what is set and restarting.
void SGExportSettings(void);
void SGImportSettings(void);

UIViewController *SGAboutPage(void);   // the Mod page
