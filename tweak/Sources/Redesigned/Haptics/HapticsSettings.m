// The Vibrations sections of the Player page, in the redesign only (App/Pages.m puts them there): a card
// per switch, the way the Audio effects page has one per effect, each opening out into its settings while
// its switch is on. Controls has its strength; Music Haptics its strength and what it follows, a choice
// that also says whether the rumble plays, rather than a switch of its own that one choice would leave
// with nothing to do.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Haptics.h"

static NSString *const kMusicHapticsInfo = @"The iPhone taps along with the drums and rumbles under the bass of whatever Spotify is playing, worked out from the sound as it plays, much like Music Haptics in Apple Music.\n\nIt follows the sound this iPhone plays, through its speaker or headphones, while Spotify is open: iOS plays no haptics for an app in the background, and a song playing on another device through Connect has no sound here to follow.";

static NSArray<NSString *> *followsNames(void) {
    return @[@"Everything", @"Beat", @"Bass"];
}

static NSArray<NSString *> *followsNotes(void) {
    return @[@"A tap on each kick and snare, and a rumble under the bass",
             @"A tap on each kick and snare, no rumble",
             @"A tap on each kick, and a rumble under the bass"];
}

static void strengthRange(NSString *key, NSInteger *minimum, NSInteger *maximum) {
    BOOL music = [key isEqualToString:SGRKeyMusicStrength];
    *minimum = music ? SGRMusicStrengthMin : SGRControlStrengthMin;
    *maximum = music ? SGRMusicStrengthMax : SGRControlStrengthMax;
}

double SGRHapticsStrength(NSString *key) {
    NSInteger minimum, maximum;
    strengthRange(key, &minimum, &maximum);
    return MAX(minimum, MIN(maximum, SGInt(key, 100))) / 100.0;
}

SGRMusicFollows SGRMusicHapticsFollows(void) {
    NSInteger follows = SGInt(SGRKeyMusicFollows, SGRMusicFollowsEverything);
    return follows >= SGRMusicFollowsEverything && follows <= SGRMusicFollowsBass ? (SGRMusicFollows)follows : SGRMusicFollowsEverything;
}

// A percentage slider over a strength key, telling `changed` each step it stores.
static SGModRow *strengthRow(NSString *key, void (^changed)(void)) {
    NSInteger minimum, maximum;
    strengthRange(key, &minimum, &maximum);
    return SGSliderRow(@"Strength", nil, minimum, maximum, SGRStrengthStep,
        ^double { return SGRHapticsStrength(key) * 100; },
        ^(double value) {
            SGSetInt(key, lround(value));
            if (changed) changed();
        },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%ld%%", lround(value)]; });
}

NSArray<SGModSection *> *SGRVibrationsSections(void) {
    SGModRow *controls = SGSwitchRow(@"Controls", @"Play, pause, skipping, scrubbing, shuffle, repeat and adding a song", SGRKeyControlHaptics);
    SGModRow *controlStrength = strengthRow(SGRKeyControlStrength, ^{
        // Felt as it is set: a tap at the new strength with each step.
        SGRPlayFeedback(SGRFeedbackAdd);
    });
    controlStrength.visible = ^BOOL { return SGEnabled(SGRKeyControlHaptics); };

    SGModRow *music = SGOptionRow(@"Music Haptics", @"Taps and rumbles along with the music", SGRKeyMusicHaptics);
    music.info = kMusicHapticsInfo;
    music.changed = ^(BOOL on) { SGRSetMusicHapticsEnabled(on); };
    BOOL (^musicOn)(void) = ^BOOL { return SGFlag(SGRKeyMusicHaptics, NO); };
    SGModRow *musicStrength = strengthRow(SGRKeyMusicStrength, ^{ SGRMusicHapticsSettingsChanged(); });
    musicStrength.visible = musicOn;
    SGModRow *follows = SGChoiceRow(@"Follows", nil, SGRKeyMusicFollows, followsNames(), SGRMusicFollowsEverything);
    follows.choiceNotes = followsNotes();
    follows.chosen = ^(NSInteger index) { SGRMusicHapticsSettingsChanged(); };
    follows.visible = musicOn;

    return @[
        SGSection(@"Vibrations", @[SGWithSymbol(controls, @"hand.tap"), controlStrength]),
        SGSection(nil, @[SGWithSymbol(music, @"waveform"), musicStrength, follows]),
    ];
}
