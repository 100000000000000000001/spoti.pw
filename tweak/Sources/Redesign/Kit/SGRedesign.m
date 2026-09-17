// The one switch of the redesign, Redesigned UI in Appearance, and the flags the redesigned screens
// force. The switch turns every redesigned screen on together: two looks, Spotify's with the mod's
// switches on it or the redesign, rather than a mix of both whose switches would cross.
#import <os/lock.h>
#import "Core/SGCore.h"
#import "SGRedesign.h"

// The screens Redesigned UI turns on; a screen added later needs only its name here.
NSArray<NSString *> *SGRedesignScreens(void) {
    return @[@"player"];
}

#pragma mark - switch

// Read once, the first time anything asks, so a switch flipped in Mod Settings waits for the restart
// like every other; the hooks, the flags and the pages all see the same answer for the whole launch.
static BOOL onAtLaunch(void) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        on = SGFlag(SGKeyRedesign, NO);
        if (on) SGLog(@"redesign: on for %@", [SGRedesignScreens() componentsJoinedByString:@", "]);
    });
    return on;
}

BOOL SGRedesignOn(NSString *screen) {
    return screen && onAtLaunch() && [SGRedesignScreens() containsObject:screen];
}

BOOL SGRedesignAnyOn(void) {
    return onAtLaunch();
}

#pragma mark - forced flags

// Written from the screens' constructors, read by the configuration provider on whatever thread it
// asks from; the lock only guards the swap of the immutable tables.
static os_unfair_lock sg_flagsLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary<NSString *, NSDictionary<NSString *, id> *> *sg_flagsByScreen;
static NSDictionary<NSString *, id> *sg_forcedNow;

void SGRedesignForceFlags(NSString *screen, NSDictionary<NSString *, id> *flags) {
    if (!screen.length || !flags.count) return;
    BOOL on = SGRedesignOn(screen);
    os_unfair_lock_lock(&sg_flagsLock);
    NSMutableDictionary *byScreen = [sg_flagsByScreen mutableCopy] ?: [NSMutableDictionary dictionary];
    byScreen[screen] = [flags copy];
    sg_flagsByScreen = [byScreen copy];
    if (on) {
        NSMutableDictionary *forced = [sg_forcedNow mutableCopy] ?: [NSMutableDictionary dictionary];
        [forced addEntriesFromDictionary:flags];
        sg_forcedNow = [forced copy];
    }
    os_unfair_lock_unlock(&sg_flagsLock);
    if (!on) return;
    SGLog(@"redesign %@: forcing %lu flags", screen, (unsigned long)flags.count);
    [flags enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        id override = SGFlagOverride(key);
        if (override) SGLog(@"redesign %@: flag %@ forced %@ over the All flags override %@", screen, key, value, override);
    }];
}

id SGRedesignForcedFlag(NSString *key) {
    if (!key || !SGRedesignAnyOn()) return nil;
    os_unfair_lock_lock(&sg_flagsLock);
    id value = sg_forcedNow[key];
    os_unfair_lock_unlock(&sg_flagsLock);
    return value;
}

id SGRedesignOwnedFlag(NSString *key) {
    if (!key || !SGFlag(SGKeyRedesign, NO)) return nil;
    os_unfair_lock_lock(&sg_flagsLock);
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *byScreen = sg_flagsByScreen;
    os_unfair_lock_unlock(&sg_flagsLock);
    for (NSString *screen in SGRedesignScreens()) {
        id value = byScreen[screen][key];
        if (value) return value;
    }
    return nil;
}
