// Donate: Ko-fi, asked for from the Mod Settings row, a button on the welcome tour and a sheet that
// comes up on its own two days after the first launch and then every fourteen.
#import <UIKit/UIKit.h>
#import "Settings/SGModPage.h"

extern NSString *const SGKofiURL;
UIColor *SGKofiColor(void);

// A glass capsule with a Ko-fi rim circling it and a breathing glow. Prominent tints the glass itself.
@interface SGKofiButton : UIControl
- (instancetype)initWithTitle:(NSString *)title prominent:(BOOL)prominent;
@end

void SGShowDonateSheet(void);
SGModRow *SGDonateRow(void);
void SGWatchForDonate(void);
