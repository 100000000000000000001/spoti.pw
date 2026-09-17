// The taps of Vibrations > Controls, one per kind of control, from UIKit's feedback generators, so they
// feel like the rest of iOS: impacts for a press that does something, selection ticks for a value moving
// under the finger (Apple's Playing haptics: impact complements a physical action, selection a changing
// value). Starting playback is a crisp tap and stopping it a soft one, so the two can be told apart
// without looking.
#import "Core/SGCore.h"
#import "Haptics.h"

typedef struct {
    NSInteger style;      // a UIImpactFeedbackStyle, or kSelection
    CGFloat intensity;
} Tap;

static const NSInteger kSelection = -1;

static Tap tapFor(SGRFeedback feedback) {
    switch (feedback) {
        case SGRFeedbackPlay: return (Tap){UIImpactFeedbackStyleRigid, 0.8};
        case SGRFeedbackPause: return (Tap){UIImpactFeedbackStyleSoft, 1};
        case SGRFeedbackSkip: return (Tap){UIImpactFeedbackStyleLight, 1};
        case SGRFeedbackToggle: return (Tap){kSelection, 1};
        case SGRFeedbackAdd: return (Tap){UIImpactFeedbackStyleMedium, 0.8};
        case SGRFeedbackGrab: return (Tap){UIImpactFeedbackStyleLight, 0.7};
        case SGRFeedbackDetent: return (Tap){kSelection, 1};
        case SGRFeedbackEdge: return (Tap){UIImpactFeedbackStyleRigid, 0.6};
        case SGRFeedbackRelease: return (Tap){UIImpactFeedbackStyleSoft, 0.8};
    }
    return (Tap){kSelection, 1};
}

static UIFeedbackGenerator *generatorFor(NSInteger style) {
    static NSMutableDictionary<NSNumber *, UIFeedbackGenerator *> *generators;
    if (!generators) generators = [NSMutableDictionary dictionary];
    UIFeedbackGenerator *generator = generators[@(style)];
    if (!generator) {
        generator = style == kSelection ? [UISelectionFeedbackGenerator new] : [[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyle)style];
        generators[@(style)] = generator;
    }
    return generator;
}

void SGRPlayFeedback(SGRFeedback feedback) {
    if (!SGEnabled(SGRKeyControlHaptics)) return;
    Tap tap = tapFor(feedback);
    UIFeedbackGenerator *generator = generatorFor(tap.style);
    if (tap.style == kSelection) [(UISelectionFeedbackGenerator *)generator selectionChanged];
    else [(UIImpactFeedbackGenerator *)generator impactOccurredWithIntensity:tap.intensity];
}

void SGRPrepareFeedback(SGRFeedback feedback) {
    if (!SGEnabled(SGRKeyControlHaptics)) return;
    [generatorFor(tapFor(feedback).style) prepare];
}
