// Vibrations, the redesign's haptics (Mod Settings > Player > Vibrations): the Taptic Engine answering
// what a finger does to playback (Controls), and playing along with the music (Music Haptics).
//
//     SGRFeedback.m        which tap each kind of control gets, played while Controls is on
//     ControlHaptics.x     the player's and the now playing bar's controls, the scrubber, the cover swipes, the gestures
//     MusicHaptics.x       Spotify's audio output listened to, and Core Haptics played along with it
//     SGRMusicAnalyzer.m   the listening: taps and a rumble out of the samples
//     HapticsSettings.m    the Vibrations cards, with each switch's strength and what Music Haptics follows
//
// Everything on them applies at once, without a restart. The lyrics page's tap to seek plays its feedback
// from Redesigned/Lyrics/SGRKaraokeView.m.
// Threading: main thread only.
#import <UIKit/UIKit.h>

#define SGRKeyControlHaptics @"spotifyglass.redesign.haptics.controls"
#define SGRKeyMusicHaptics @"spotifyglass.redesign.haptics.music"
// How hard the taps are, a percentage within the range below; 100 is the feel each shipped with.
#define SGRKeyControlStrength @"spotifyglass.redesign.haptics.controls.strength"
#define SGRKeyMusicStrength @"spotifyglass.redesign.haptics.music.strength"
// What Music Haptics plays along with, an SGRMusicFollows.
#define SGRKeyMusicFollows @"spotifyglass.redesign.haptics.music.follows"

// Controls go softer only: most of their taps are UIKit's at full intensity already. Music Haptics goes
// either way: at 200% the rumble reaches 0.7 of the Taptic Engine's most, and most taps their most.
enum {
    SGRControlStrengthMin = 10, SGRControlStrengthMax = 100,
    SGRMusicStrengthMin = 20, SGRMusicStrengthMax = 200,
    SGRStrengthStep = 10,
};

typedef NS_ENUM(NSInteger, SGRMusicFollows) {
    SGRMusicFollowsEverything,   // a tap on each kick and snare, and the rumble under the bass
    SGRMusicFollowsBeat,         // a tap on each kick and snare, no rumble
    SGRMusicFollowsBass,         // a tap on each kick, and the rumble
};

typedef NS_ENUM(NSInteger, SGRFeedback) {
    SGRFeedbackPlay,      // playback starts
    SGRFeedbackPause,     // playback stops
    SGRFeedbackSkip,      // previous, next, a jump in the song (a double tap, a lyric line)
    SGRFeedbackToggle,    // shuffle, repeat
    SGRFeedbackAdd,       // the add button: liked songs, a playlist
    SGRFeedbackGrab,      // a finger takes the scrubber
    SGRFeedbackDetent,    // the scrubber passing a tenth of the song, a cover swipe passing halfway
    SGRFeedbackEdge,      // the scrubber reaching the start or the end
    SGRFeedbackRelease,   // the scrubber let go
};

// Plays `feedback` while Controls is on.
void SGRPlayFeedback(SGRFeedback feedback);
// Wakes the Taptic Engine for feedback about to follow quickly (a finger on the scrubber).
void SGRPrepareFeedback(SGRFeedback feedback);

// From the Music Haptics switch: starts or stops listening at once.
void SGRSetMusicHapticsEnabled(BOOL on);
// From its strength and its choice of what to follow: reads them again, for the next tap.
void SGRMusicHapticsSettingsChanged(void);

// A strength key's percentage as a factor, 1 for 100%, kept within its range.
double SGRHapticsStrength(NSString *key);
SGRMusicFollows SGRMusicHapticsFollows(void);

@class SGModSection;
// The Vibrations sections of the Player page: a card for Controls and one for Music Haptics, each opening
// out into its settings while its switch is on.
NSArray<SGModSection *> *SGRVibrationsSections(void);
