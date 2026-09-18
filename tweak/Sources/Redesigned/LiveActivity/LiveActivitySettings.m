// The Live Activity row of the Lyrics page, in the redesign only (App/Pages.m puts it there).
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "LiveActivity.h"

SGModRow *SGRLiveActivityRow(void) {
    SGModRow *row = SGOptionRow(@"Live Activity", @"The line being sung on the lock screen and in the Dynamic Island", SGRKeyLiveActivity);
    row.changed = ^(BOOL on) { SGRSetLiveActivityEnabled(on); };
    return row;
}
