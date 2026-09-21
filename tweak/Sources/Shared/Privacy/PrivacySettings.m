#import "Settings/SGModPage.h"
#import "Privacy.h"

SGModSection *SGPrivacySection(void) {
    return SGSection(@"Privacy", @[
        SGWithSymbol(SGSwitchRow(@"Block telemetry", @"Answer the analytics of the SDKs Spotify carries (Firebase, Crashlytics, Comscore...) with an empty reply instead of letting the request out. Spotify's own events go out, since Recents is built from them", SGKeyBlockTelemetry), @"antenna.radiowaves.left.and.right.slash"),
    ]);
}

SGModSection *SGPrivacyCountersSection(void) {
    NSMutableArray<SGModRow *> *counts = [NSMutableArray array];
    for (NSString *label in SGBlockedLabels()) {
        [counts addObject:SGStatRow(label, ^NSString *{
            return @(SGBlockedCount(label)).stringValue;
        })];
    }
    [counts addObject:SGStatRow(@"Total", ^NSString *{
        return @(SGBlockedCount(nil)).stringValue;
    })];
    [counts addObject:SGActionRow(@"Reset the telemetry counters", @"Start counting from zero", ^{ SGResetBlocked(); })];
    return SGSection(@"Telemetry blocked so far", counts);
}
