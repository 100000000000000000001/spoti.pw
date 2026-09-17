// The switches of the redesigned screens and the flags they force. A screen's switch is the tab its
// part's settings page picks it with (the Player page's Native player and Redesigned player).
#import <os/lock.h>
#import "Core/SGCore.h"
#import "SGRedesign.h"

// A screen added later needs its name here and a way to pick it on its part's settings page.
NSArray<NSString *> *SGRedesignScreens(void) {
    return @[@"player"];
}

static NSString *keyFor(NSString *screen) {
    return [SGKeyRedesignPrefix stringByAppendingString:screen];
}

#pragma mark - switches

// Read once, the first time anything asks, so a switch flipped in Mod Settings waits for the restart
// like every other; the hooks, the flags and the pages all see the same answer for the whole launch.
static NSSet<NSString *> *onAtLaunch(void) {
    static NSSet<NSString *> *on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableSet *found = [NSMutableSet set];
        for (NSString *screen in SGRedesignScreens()) {
            if (SGFlag(keyFor(screen), NO)) [found addObject:screen];
        }
        on = [found copy];
        if (on.count) SGLog(@"redesign: on for %@", [on.allObjects componentsJoinedByString:@", "]);
    });
    return on;
}

BOOL SGRedesignOn(NSString *screen) {
    return screen && [onAtLaunch() containsObject:screen];
}

BOOL SGRedesignAnyOn(void) {
    return onAtLaunch().count > 0;
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
        if (override) SGLog(@"redesign %@: flag %@ forced %@, the All flags override %@ wins", screen, key, value, override);
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
    if (!key) return nil;
    os_unfair_lock_lock(&sg_flagsLock);
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *byScreen = sg_flagsByScreen;
    os_unfair_lock_unlock(&sg_flagsLock);
    for (NSString *screen in SGRedesignScreens()) {
        id value = byScreen[screen][key];
        if (value && SGFlag(keyFor(screen), NO)) return value;
    }
    return nil;
}
