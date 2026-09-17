#import "SGUIMode.h"
#import "SGLog.h"
#import "SGPrefs.h"

BOOL SGRedesignedUI(void) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        on = SGFlag(SGKeyRedesign, NO);
        SGLog(@"ui: %@", on ? @"redesigned" : @"native");
    });
    return on;
}

BOOL SGNativeUI(void) {
    return !SGRedesignedUI();
}

BOOL SGRedesignedUIStored(void) {
    return SGFlag(SGKeyRedesign, NO);
}
