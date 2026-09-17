// Glass for the redesign's control layer, and only for it: never behind rows, cards or text. Adjacent
// glass shares one UIGlassContainerEffect, since glass cannot sample glass, and glass that takes a
// touch is interactive. Built on Core/SGGlass.m (the effect made through +effectWithStyle:).
//
// Two stand-ins, chosen as a piece is laid out: under Reduce Transparency every shape and button is a
// solid SGRSolidGlassFill (a light fill for a prominent button), on any OS; before iOS 26 without it,
// a dark thin material blur with no container. Nothing touches a glass class on an OS without them.
//
// Ownership: a backing belongs to its host (associated with it under the caller's key); buttons and
// the action row belong to whoever adds them.
// Threading: main thread only.
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, SGRGlassShape) {
    SGRGlassCircle,    // round, from the frame's shorter side
    SGRGlassCapsule,
};

// Glass behind someone else's controls: one container spanning the host, behind everything the host
// draws (zPosition -1), holding a shape per frame, taking no touches, so Spotify's own buttons keep
// their actions, state and accessibility on top of it.
@interface SGRGlassBacking : UIView
// The host's backing under `key`, made on first use and put back at the bottom of the host whenever
// something moved it.
+ (instancetype)backingInHost:(UIView *)host key:(const void *)key;
// Frames in the host's coordinates; shapes are reused, and those past the count are hidden.
- (void)setShapes:(NSArray<NSValue *> *)framesInHost shape:(SGRGlassShape)shape;
@end

// A glass circle inside someone else's round control, `side` across, behind everything the control
// draws (zPosition -1) and kept at its middle by the autoresizing mask. Being the control's own
// subview it goes wherever the control goes: a frame worked out from outside goes stale when Spotify
// lays a row out after the unit that holds it (the player's header circles sat 24pt off until a tap
// laid the unit out again, trees/continuous/1.txt 2026-09-17). Takes no touches; made once per control
// under `key`, and made again when Reduce Transparency changes the kind of shape.
UIView *SGRGlassInside(UIView *control, const void *key, CGFloat side);

// A glass button of the redesign's own: a circle with a symbol, or a capsule with a symbol and a
// title, prominent (light glass, dark content) for the one main action of a screen. UIKit's glass
// button configuration on iOS 26, with its own press response; a spring to 0.96 on the stand-ins.
@interface SGRGlassButton : UIButton
+ (instancetype)circleWithSymbol:(NSString *)symbol accessibilityLabel:(NSString *)label;
+ (instancetype)capsuleWithSymbol:(NSString *)symbol title:(NSString *)title prominent:(BOOL)prominent;
@property (nonatomic, copy) void (^onTap)(void);
// On tints the symbol with SGRAccent (shuffle on, following); it is also the accessibility value.
@property (nonatomic, getter=isOn) BOOL on;
// A symbol swap replaces the glyph with UIKit's symbol transition (none under Reduce Motion); a title
// swap crossfades. The same symbol or title again is a no-op.
- (void)setSymbol:(NSString *)symbol animated:(BOOL)animated;
- (void)setTitle:(NSString *)title animated:(BOOL)animated;
@end

// A centred row of glass buttons in one container, SGRActionSpacing apart and SGRActionHeight tall:
// circles SGRActionHeight wide, a prominent capsule at least 132, other capsules 96 to 140. Its
// own touches pass through; only the buttons take them.
@interface SGRActionRow : UIView
@property (nonatomic, copy) NSArray<UIButton *> *buttons;
@end
