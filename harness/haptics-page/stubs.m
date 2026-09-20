// Music Haptics' side of Haptics.h (MusicHaptics.x in the tweak), which the page calls as its switch and its
// settings change: each call is logged with what the hook would read at that moment.
#import "Core/SGCore.h"
#import "Redesigned/Haptics/Haptics.h"

void SGRSetMusicHapticsEnabled(BOOL on) {
    NSLog(@"[harness] Music Haptics %@", on ? @"on" : @"off");
}

void SGRMusicHapticsSettingsChanged(void) {
    NSLog(@"[harness] Music Haptics reads strength %.0f%%, follows %ld", SGRHapticsStrength(SGRKeyMusicStrength) * 100, (long)SGRMusicHapticsFollows());
}
