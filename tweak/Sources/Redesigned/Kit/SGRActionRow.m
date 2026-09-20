// The action row's controls: the Play capsule and the button that stands in for one of Spotify's.
//
// Both are drawn from what Spotify's own button shows, and neither keeps state of its own. The glyph is
// looked for past what is hidden behind it -- a play button's glow ring is a hidden view holding an image
// of its own, and taken for the glyph it put a soft green ring in the capsule (device, 2026-09-17) -- and
// it is watched afterwards, because Spotify swaps play for pause without laying the header out again.
#import "Core/SGCore.h"
#import "SGRActionRow.h"
#import "SGRGlass.h"
#import "SGRRestyle.h"
#import "SGRTokens.h"
#import "SGRAccent.h"

// The capsule: the glyph is Spotify's own 48pt canvas with the triangle small in the middle of it, so the
// lead is short and the gap to the word comes out of the canvas itself.
static const CGFloat kGlyphSide = 44, kCapsuleLead = 4, kCapsuleTrail = 20;
// The mirrored glyph, the size Spotify draws one inside a 48pt round button.
static const CGFloat kMirrorGlyph = 24;

static char kCapsuleGlassKey, kMirrorGlassKey, kWordGlassKey;

// A word button's padding either side of the word.
static const CGFloat kWordPadding = 18;

#pragma mark - firing Spotify's button

// The way a tap on Spotify's own button would: its first control, fired through its actions, and through
// accessibility for an Encore control that reads its touches from a gesture recognizer instead.
static void fire(UIView *source) {
    __block UIControl *control = nil;
    SGForEachView(source, ^(UIView *v) {
        if (!control && [v isKindOfClass:UIControl.class]) control = (UIControl *)v;
    });
    if (control && SGRFire(control)) return;
    id target = control ?: source;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"redesign kit: an action row control fired through accessibility on %@", [target class]); });
    [target accessibilityActivate];
}

// The glyph Spotify's button draws: an image view of the button's own size that nothing hidden is in the
// way of. `side` is the size to match, 0 for any image view that is showing.
static UIImageView *glyphIn(UIView *button, CGFloat side) {
    __block UIImageView *glyph = nil;
    SGForEachView(button, ^(UIView *v) {
        if (glyph || ![v isKindOfClass:UIImageView.class] || !((UIImageView *)v).image) return;
        if (side > 0 && (fabs(v.bounds.size.width - side) > 2 || fabs(v.bounds.size.height - side) > 2)) return;
        for (UIView *up = v; up && up != button; up = up.superview) {
            if (up.hidden || up.alpha <= 0.01) return;
        }
        glyph = (UIImageView *)v;
    });
    return glyph;
}

static NSString *wordIn(UIView *button) {
    __block NSString *word = nil;
    SGForEachView(button, ^(UIView *v) {
        if (!word && v.accessibilityLabel.length) word = v.accessibilityLabel;
    });
    return word;
}

#pragma mark - the Play capsule

@implementation SGRPlayCapsule {
    UIImageView *_glyph;
    UILabel *_title;
    __weak UIImageView *_watchedGlyph;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _glyph = [UIImageView new];
    _glyph.contentMode = UIViewContentModeScaleAspectFit;
    _glyph.userInteractionEnabled = NO;
    [self addSubview:_glyph];

    _title = [UILabel new];
    _title.userInteractionEnabled = NO;
    [self addSubview:_title];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self addTarget:self action:@selector(sgr_down) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(sgr_up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self addTarget:self action:@selector(sgr_tap) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (CGFloat)sgr_width {
    [_title sizeToFit];
    return kCapsuleLead + kGlyphSide + ceil(_title.bounds.size.width) + kCapsuleTrail;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    if (self.fillColor) {
        if (![self.backgroundColor isEqual:self.fillColor]) self.backgroundColor = self.fillColor;
        self.layer.cornerRadius = bounds.size.height / 2;
        self.layer.cornerCurve = kCACornerCurveContinuous;
    } else {
        SGRGlassCapsuleInside(self, &kCapsuleGlassKey, bounds.size, YES);
    }
    // Given more room than the word asks for, the glyph and the word stay together in the middle.
    CGFloat lead = kCapsuleLead + MAX(0, round((bounds.size.width - [self sgr_width]) / 2));
    _glyph.frame = CGRectMake(lead, round((bounds.size.height - kGlyphSide) / 2), kGlyphSide, kGlyphSide);
    // Spotify's glyph comes on a 48pt canvas and is scaled down into the frame; one drawn tight is shown at
    // its own size instead of blown up to fill it.
    CGSize image = _glyph.image.size;
    UIViewContentMode mode = image.width <= kGlyphSide && image.height <= kGlyphSide ? UIViewContentModeCenter : UIViewContentModeScaleAspectFit;
    if (_glyph.contentMode != mode) _glyph.contentMode = mode;
    [_title sizeToFit];
    CGSize text = _title.bounds.size;
    _title.frame = CGRectMake(CGRectGetMaxX(_glyph.frame), round((bounds.size.height - text.height) / 2),
                              MAX(0, bounds.size.width - kCapsuleTrail - CGRectGetMaxX(_glyph.frame)), text.height);
}

- (void)feedFrom:(UIView *)source {
    if (!source) return;
    _source = source;

    NSString *word = wordIn(source);
    // The disc is as tall as the button, not always as wide: Liked Songs' is 80x48 with the 48pt disc at
    // x=16 (trees/continuous/1.txt, 2026-09-18), and matched by width the capsule drew no glyph at all.
    CGSize size = source.bounds.size;
    UIImageView *glyph = glyphIn(source, MIN(size.width, size.height));

    UIFont *font = SGRFont(UIFontTextStyleSubheadline, UIFontWeightSemibold, UIContentSizeCategoryLarge);
    if (![_title.font isEqual:font]) _title.font = font;
    UIColor *content = self.contentColor ?: SGRAccent();
    if (![_title.textColor isEqual:content]) _title.textColor = content;
    if (word && ![_title.text isEqualToString:word]) {
        _title.text = word;
        self.accessibilityLabel = word;
        [self setNeedsLayout];
    }
    if (![_glyph.tintColor isEqual:content]) _glyph.tintColor = content;

    if (glyph.image && _glyph.image != glyph.image) {
        _glyph.image = [glyph.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            SGLog(@"redesign kit: play glyph %@ from %@, word \"%@\"", NSStringFromCGSize(glyph.image.size),
                  NSStringFromClass(glyph.class), word);
        });
    }
    // Play becomes pause without the header laying out again. Watched per glyph view rather than once for
    // good, so a glyph Spotify hands to another button reports to the button it is in now.
    if (glyph && glyph != _watchedGlyph) {
        _watchedGlyph = glyph;
        __weak SGRPlayCapsule *weakSelf = self;
        __weak UIView *weakSource = source;
        SGRObserveImage(glyph, ^(UIImageView *view) {
            if (weakSelf && weakSource) [weakSelf feedFrom:weakSource];
        });
    }
}

- (void)sgr_down {
    SGRAnimate(SGRMotionPress, ^{ self.transform = CGAffineTransformMakeScale(0.94, 0.94); }, nil);
}

- (void)sgr_up {
    SGRAnimate(SGRMotionPress, ^{ self.transform = CGAffineTransformIdentity; }, nil);
}

- (void)sgr_tap {
    fire(self.source);
}

@end

#pragma mark - a button standing in for Spotify's

// The label a button shows its word in, whether it has a word in it yet or not.
static UILabel *labelIn(UIView *button) {
    __block UILabel *found = nil;
    SGForEachView(button, ^(UIView *v) {
        if (!found && [v isKindOfClass:UILabel.class]) found = (UILabel *)v;
    });
    return found;
}

// The text a button shows: the first label under it with something in it.
static NSString *labelTextIn(UIView *button) {
    __block NSString *text = nil;
    SGForEachView(button, ^(UIView *v) {
        if (text || ![v isKindOfClass:UILabel.class]) return;
        NSString *candidate = [((UILabel *)v).text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (candidate.length) text = candidate;
    });
    return text;
}

@implementation SGRMirrorButton {
    UIImageView *_glyph;
    UILabel *_word;
    __weak UILabel *_watchedWord;
    __weak UIImageView *_watchedGlyph;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _glyph = [UIImageView new];
    _glyph.contentMode = UIViewContentModeScaleAspectFit;
    _glyph.userInteractionEnabled = NO;
    [self addSubview:_glyph];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self addTarget:self action:@selector(sgr_down) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(sgr_up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self addTarget:self action:@selector(sgr_tap) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (CGFloat)sgr_width {
    if (!self.showsWord || !_word.text.length) return SGRActionHeight;
    [_word sizeToFit];
    return MAX(SGRActionHeight, ceil(_word.bounds.size.width) + 2 * kWordPadding);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    // A word button waiting for its word draws the circle, and takes the capsule once the word is there:
    // only one of the two shapes is asked for on a pass, so the other is put away rather than left under it.
    if (self.showsWord && _word.text.length) {
        SGRGlassCapsuleInside(self, &kWordGlassKey, bounds.size, NO);
        ((UIView *)objc_getAssociatedObject(self, &kMirrorGlassKey)).hidden = YES;
        [_word sizeToFit];
        CGSize text = _word.bounds.size;
        // Given less width than the word asked for -- what is left of the row beside a wide Play -- the
        // capsule spends its own padding on the word before it lets the word be cut ("Following").
        CGFloat padding = MIN(kWordPadding, MAX(0, floor((bounds.size.width - text.width) / 2)));
        _word.frame = CGRectMake(padding, round((bounds.size.height - text.height) / 2),
                                 MAX(0, bounds.size.width - 2 * padding), text.height);
        return;
    }
    SGRGlassInside(self, &kMirrorGlassKey, SGRGlassCircleSize);
    ((UIView *)objc_getAssociatedObject(self, &kWordGlassKey)).hidden = YES;
    _glyph.frame = CGRectMake(round((bounds.size.width - kMirrorGlyph) / 2), round((bounds.size.height - kMirrorGlyph) / 2),
                              kMirrorGlyph, kMirrorGlyph);
}

// The glyph is taken as Spotify drew it, colour and all: the shuffle button turns its own glyph the accent
// colour while shuffle is on, and a copy rendered as a template would lose that.
- (void)feedFrom:(UIView *)source {
    if (!source) return;
    _source = source;

    if (self.showsWord) {
        if (!_word) {
            _word = [UILabel new];
            _word.userInteractionEnabled = NO;
            _word.textAlignment = NSTextAlignmentCenter;
            _word.font = SGRFont(UIFontTextStyleSubheadline, UIFontWeightSemibold, UIContentSizeCategoryExtraLarge);
            _word.textColor = SGRPrimary();
            [self addSubview:_word];
        }
        NSString *text = labelTextIn(source);
        if (text && ![_word.text isEqualToString:text]) {
            _word.text = text;
            self.accessibilityLabel = source.accessibilityLabel ?: text;
            [self setNeedsLayout];
            [self.superview setNeedsLayout];
        }
        // Spotify's word is its state, which it fills in a moment after the button itself is there and
        // changes without laying out anything the page hears (the artist's Follow, issue #52). So the label
        // it puts the word in is watched, and the button hears it land.
        UILabel *source_word = labelIn(source);
        if (source_word && source_word != _watchedWord) {
            _watchedWord = source_word;
            __weak SGRMirrorButton *weakSelf = self;
            __weak UIView *weakSource = source;
            SGRObserveText(source_word, ^(UILabel *label) {
                if (weakSelf && weakSource) [weakSelf feedFrom:weakSource];
            });
        }
        // Until the word is there the button is the glyph it falls back to, which says what it does, rather
        // than an empty capsule.
        BOOL hasWord = _word.text.length > 0;
        if (_glyph.hidden != hasWord) {
            _glyph.hidden = hasWord;
            [self setNeedsLayout];
        }
        if (!hasWord && self.fallbackGlyph && _glyph.image != self.fallbackGlyph) {
            _glyph.image = self.fallbackGlyph;
            _glyph.tintColor = SGRPrimary();
        }
        if (!hasWord && !self.accessibilityLabel) self.accessibilityLabel = source.accessibilityLabel;
        return;
    }

    UIImageView *glyph = glyphIn(source, 0);
    NSString *word = source.accessibilityLabel ?: wordIn(source);
    if (word && ![self.accessibilityLabel isEqualToString:word]) self.accessibilityLabel = word;
    if (glyph.image && _glyph.image != glyph.image) _glyph.image = glyph.image;
    if (glyph.tintColor && ![_glyph.tintColor isEqual:glyph.tintColor]) _glyph.tintColor = glyph.tintColor;
    if (!glyph && self.fallbackGlyph && _glyph.image != self.fallbackGlyph) {
        _glyph.image = self.fallbackGlyph;
        _glyph.tintColor = SGRPrimary();
    }

    // As the capsule does: watched per glyph view, so a reused one reports where it is now.
    if (glyph && glyph != _watchedGlyph) {
        _watchedGlyph = glyph;
        __weak SGRMirrorButton *weakSelf = self;
        __weak UIView *weakSource = source;
        SGRObserveImage(glyph, ^(UIImageView *view) {
            if (weakSelf && weakSource) [weakSelf feedFrom:weakSource];
        });
    }
}

- (void)sgr_down {
    SGRAnimate(SGRMotionPress, ^{ self.transform = CGAffineTransformMakeScale(0.92, 0.92); }, nil);
}

- (void)sgr_up {
    SGRAnimate(SGRMotionPress, ^{ self.transform = CGAffineTransformIdentity; }, nil);
}

- (void)sgr_tap {
    fire(self.source);
    // The word is watched where Spotify writes it, but a button that rebuilds its content on the state it
    // just took writes the new word into a label the watch has never seen. So a tap, and only a tap, asks
    // the button again a moment later, which also moves the watch onto whatever label it ended up with.
    if (!self.showsWord) return;
    __weak SGRMirrorButton *weakSelf = self;
    for (NSNumber *delay in @[@0.3, @1.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SGRMirrorButton *button = weakSelf;
            if (button.source) [button feedFrom:button.source];
        });
    }
}

@end
