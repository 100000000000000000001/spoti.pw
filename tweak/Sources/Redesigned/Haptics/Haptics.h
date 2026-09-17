// Vibrations, the redesign's haptics (Mod Settings > Player > Vibrations): the Taptic Engine answering
// what a finger does to playback (Controls), and playing along with the music (Music Haptics).
//
//     SGRFeedback.m        which tap each kind of control gets, played while Controls is on
//     ControlHaptics.x     the player's and the now playing bar's controls, the scrubber, the cover swipes, the gestures
//     MusicHaptics.x       Spotify's audio output listened to, and Core Haptics played along with it
//     SGRMusicAnalyzer.m   the listening: taps and a rumble out of the samples
//     HapticsSettings.m    the Vibrations section
//
// Both switches apply at once, without a restart. The lyrics page's tap to seek plays its feedback from
// Redesigned/Lyrics/SGRKaraokeView.m.
// Threading: main thread only.
#import <UIKit/UIKit.h>

#define SGRKeyControlHaptics @"spotifyglass.redesign.haptics.controls"
#define SGRKeyMusicHaptics @"spotifyglass.redesign.haptics.music"

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

@class SGModSection;
// The Vibrations section of the Player page.
SGModSection *SGRVibrationsSection(void);
