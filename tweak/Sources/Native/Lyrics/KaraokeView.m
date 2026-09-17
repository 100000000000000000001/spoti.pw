#import "Core/SGCore.h"
#import "Native/Lyrics/KaraokeView.h"
#import "Shared/LyricsSources/LyricsSources.h"
#import "Shared/Player/PlayerEvents.h"

static const CGFloat kFontSize = 30, kMargin = 24, kLineGap = 24, kRowTighten = 2;
// The card under the player is a seventh of the page's height, so it gets Spotify's own card type
// size and the spacing its rows sit on, and no blur: at that size the dimming does the work, and a
// blur filter on every line in sight, under the card's glass, made the player stutter as it opened.
static const CGFloat kCardFontSize = 21, kCardMargin = 0, kCardLineGap = 16;
static const CGFloat kDimAlpha = 0.3, kFillEdge = 22, kLift = 2.5, kDimScale = 0.97;
static const CGFloat kAnchor = 0.28;   // where the sung line rests, as a share of the height
static const CGFloat kEdgeFade = 0.1;  // the lines fade out over this share at the top and bottom
static const CGFloat kBlurPerLine = 1.4, kMaxBlur = 6;
// The (oh, aye) hanging under a line: smaller, a little dimmer, and just clear of it.
static const CGFloat kBackingScale = 0.62, kBackingAlpha = 0.8, kBackingGap = 4;
// The line naming the source, under the lyrics and outside the fade so it does not dim with them.
static const CGFloat kCreditSize = 12, kCreditAlpha = 0.4, kCreditBottom = 10;
static const NSTimeInterval kBrowseHold = 3;   // after scrolling by hand, how long until it follows the song again
static const double kFloatMinMs = 700, kFloatLeadMs = 80;   // a short word still floats up this slowly
static const double kClockSnapMs = 250, kClockPull = 0.08;
// Lines get views this far outside the visible part, in screen heights: half a screen above it
// and below, and a quarter more before a view is let go. The card under the player is in the tree
// for every open and close of the player, and every view it holds is one more for the window to
// take in and let go; a line comes into view about once in three seconds, and a page flung by
// hand fills in at a few lines a frame.
static const CGFloat kSightBehind = 0.5, kSightAhead = 0.5, kSightSlack = 0.25;
static const NSTimeInterval kTransitionSlack = 0.05;   // after the player's animation, before the link is back
static NSString *const kBlurPath = @"filters.gaussianBlur.inputRadius";

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

static UILabel *wordLabel(NSString *text, UIFont *font, UIColor *color, CGRect frame) {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.font = font;
    label.textColor = color;
    return label;
}

#pragma mark - a word

// The word twice: dim underneath, white on top behind a mask whose feathered edge slides across it.
@interface SGKaraokeWordView : UIView
@property (nonatomic, readonly) SGKaraokeWord *word;
@property (nonatomic, readonly) UILabel *lit;
@property (nonatomic) CGFloat offset;   // where the word starts along its line, rows laid end to end
- (void)fillTo:(CGFloat)cursor;
- (void)floatAt:(double)ms;
- (void)settle;
@end

@implementation SGKaraokeWordView {
    CAGradientLayer *_fill;
    CGFloat _filled, _lift;
}

- (instancetype)initWithWord:(SGKaraokeWord *)word font:(UIFont *)font {
    CGSize size = [word.text sizeWithAttributes:@{NSFontAttributeName: font}];
    self = [super initWithFrame:CGRectMake(0, 0, ceil(size.width), ceil(font.lineHeight))];
    if (!self) return nil;
    _word = word;
    [self addSubview:wordLabel(word.text, font, [UIColor colorWithWhite:1 alpha:kDimAlpha], self.bounds)];
    _lit = wordLabel(word.text, font, UIColor.whiteColor, self.bounds);
    // Hidden until the line is sung: a masked layer is drawn offscreen every frame even when the
    // mask leaves nothing of it, and a song has hundreds of words waiting their turn.
    _lit.hidden = YES;
    [self addSubview:_lit];

    CGFloat width = self.bounds.size.width + kFillEdge;
    _fill = [CAGradientLayer layer];
    _fill.colors = @[(id)UIColor.whiteColor.CGColor, (id)UIColor.whiteColor.CGColor, (id)UIColor.clearColor.CGColor];
    _fill.locations = @[@0, @((width - kFillEdge) / width), @1];
    _fill.startPoint = CGPointMake(0, 0.5);
    _fill.endPoint = CGPointMake(1, 0.5);
    _lit.layer.mask = _fill;
    _filled = NAN;
    [self fillTo:-CGFLOAT_MAX];
    return self;
}

// The cursor is in line units and the feathered edge is centred on it, so the edge runs on through
// the space into the next word instead of starting over at each one.
- (void)fillTo:(CGFloat)cursor {
    CGFloat width = self.bounds.size.width, height = self.bounds.size.height;
    CGFloat local = MAX(-kFillEdge / 2, MIN(width + kFillEdge / 2, cursor - _offset));
    if (local == _filled) return;
    _filled = local;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fill.frame = CGRectMake(local - kFillEdge / 2 - width, -height / 2, width + kFillEdge, height * 2);
    [CATransaction commit];
}

// Rises like a critically damped spring let go as the word starts: no jolt, a long soft landing.
// x = 5 at the end of the word is 96 % of the way up.
- (void)floatAt:(double)ms {
    double x = MAX(0, ms - _word.start + kFloatLeadMs) / MAX(_word.end - _word.start, kFloatMinMs) * 5;
    CGFloat lift = kLift * (1 - (1 + x) * exp(-x));
    if (lift == _lift) return;
    _lift = lift;
    self.transform = CGAffineTransformMakeTranslation(0, -lift);
}

- (void)settle {
    _lift = 0;
    self.transform = CGAffineTransformIdentity;
}

@end

#pragma mark - a line

@interface SGKaraokeLineView : UIView
@property (nonatomic, readonly) SGKaraokeLine *line;
@property (nonatomic) BOOL active;
@property (nonatomic) CGFloat blur;
- (instancetype)initWithLine:(SGKaraokeLine *)line width:(CGFloat)width font:(UIFont *)font backing:(BOOL)backing blurred:(BOOL)blurred;
- (void)showTime:(double)ms;
@end

typedef struct {
    double ms, x, slope;
} SGSweepKnot;

@implementation SGKaraokeLineView {
    NSArray<SGKaraokeWordView *> *_words;
    NSUInteger _generation;
    SGSweepKnot *_knots;
    NSUInteger _knotCount;
    SGKaraokeLineView *_backing;
}

- (instancetype)initWithLine:(SGKaraokeLine *)line width:(CGFloat)width font:(UIFont *)font backing:(BOOL)backing blurred:(BOOL)blurred {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _line = line;
    CGFloat space = ceil([@" " sizeWithAttributes:@{NSFontAttributeName: font}].width);
    CGFloat row = ceil(font.lineHeight) - kRowTighten, x = 0, y = 0, offset = 0;
    NSMutableArray<SGKaraokeWordView *> *words = [NSMutableArray array];
    NSMutableArray<NSMutableArray<SGKaraokeWordView *> *> *rows = [NSMutableArray arrayWithObject:[NSMutableArray array]];
    for (SGKaraokeWord *word in line.words) {
        SGKaraokeWordView *view = [[SGKaraokeWordView alloc] initWithWord:word font:font];
        CGSize size = view.bounds.size;
        // A joined word follows the one before it flush: the scripts that do not space their words
        // would otherwise read with a gap between every syllable.
        CGFloat lead = x > 0 && !word.joined ? space : 0;
        if (x > 0 && x + lead + size.width > width) {
            x = lead = 0;
            y += row;
            [rows addObject:[NSMutableArray array]];
        }
        x += lead;
        offset += lead;
        view.center = CGPointMake(x + size.width / 2, y + size.height / 2);
        view.offset = offset;
        x += size.width;
        offset += size.width;
        [self addSubview:view];
        [words addObject:view];
        [rows.lastObject addObject:view];
    }
    // A second voice is laid against the far edge, as Apple Music sets the two sides of a duet apart.
    if (line.align == SGKaraokeAlignTrailing) {
        for (NSArray<SGKaraokeWordView *> *wrapped in rows) {
            if (!wrapped.count) continue;
            CGFloat shift = width - CGRectGetMaxX(wrapped.lastObject.frame);
            if (shift <= 0) continue;
            for (SGKaraokeWordView *view in wrapped) view.center = CGPointMake(view.center.x + shift, view.center.y);
        }
    }
    _words = words;

    CGFloat height = y + ceil(font.lineHeight);
    if (line.backing.words.count && !backing) {
        UIFont *smaller = [UIFont systemFontOfSize:round(font.pointSize * kBackingScale) weight:UIFontWeightBold];
        _backing = [[SGKaraokeLineView alloc] initWithLine:line.backing width:width font:smaller backing:YES blurred:NO];
        _backing.alpha = kBackingAlpha;
        _backing.frame = CGRectMake(0, height + kBackingGap, width, _backing.bounds.size.height);
        [self addSubview:_backing];
        height = CGRectGetMaxY(_backing.frame);
    }
    self.frame = CGRectMake(0, 0, width, height);
    [self buildSweep];

    // Scales toward the edge its text is aligned to, and a backing row rides its line's blur.
    if (backing) return self;
    self.layer.anchorPoint = CGPointMake(line.align == SGKaraokeAlignTrailing ? 1 : 0, 0.5);
    if (!blurred) return self;
    CAFilter *blur = [NSClassFromString(@"CAFilter") filterWithType:@"gaussianBlur"];
    if (blur) self.layer.filters = @[blur];
    return self;
}

// The height a line takes at a width, its rows counted the way initWithLine:width:font:backing:blurred:
// lays them, so the page can place every line of a song while making views for the few in sight.
static CGFloat lineHeight(SGKaraokeLine *line, CGFloat width, UIFont *font, BOOL backing) {
    CGFloat space = ceil([@" " sizeWithAttributes:@{NSFontAttributeName: font}].width);
    CGFloat row = ceil(font.lineHeight) - kRowTighten, x = 0, y = 0;
    for (SGKaraokeWord *word in line.words) {
        CGFloat wordWidth = ceil([word.text sizeWithAttributes:@{NSFontAttributeName: font}].width);
        CGFloat lead = x > 0 && !word.joined ? space : 0;
        if (x > 0 && x + lead + wordWidth > width) {
            x = lead = 0;
            y += row;
        }
        x += lead + wordWidth;
    }
    CGFloat height = y + ceil(font.lineHeight);
    if (line.backing.words.count && !backing) {
        UIFont *smaller = [UIFont systemFontOfSize:round(font.pointSize * kBackingScale) weight:UIFontWeightBold];
        height += kBackingGap + lineHeight(line.backing, width, smaller, YES);
    }
    return height;
}

// Where each line starts in the stack, from the heights alone. Measuring text is safe off the main
// thread, and a song's worth of it is kept off it: the first card of a track lays out while the
// player is opening, and a frame that measured every line then was a frame the animation lost.
static NSArray<NSNumber *> *topsOf(NSArray<SGKaraokeLine *> *lines, CGFloat width, UIFont *font, CGFloat gap) {
    NSMutableArray<NSNumber *> *tops = [NSMutableArray arrayWithCapacity:lines.count];
    CGFloat top = 0;
    for (SGKaraokeLine *line in lines) {
        [tops addObject:@(top)];
        top += lineHeight(line, width, font, NO) + gap;
    }
    return tops;
}

// How many line views are made in one frame: the rest follow on the next, nearest the sung line first.
static const NSUInteger kLinesPerFrame = 4;

- (void)dealloc {
    free(_knots);
}

static double secant(SGSweepKnot *knots, NSUInteger i) {
    return (knots[i + 1].x - knots[i].x) / (knots[i + 1].ms - knots[i].ms);
}

// The fill cursor reaches each word's left edge as the word starts and clears the last word as it
// ends, on a monotone cubic through those points, so the pace changes between words without a kink.
- (void)buildSweep {
    _knots = calloc(_words.count + 1, sizeof(SGSweepKnot));
    if (!_words.count) return;
    for (NSUInteger i = 0; i <= _words.count; i++) {
        SGKaraokeWordView *word = _words[MIN(i, _words.count - 1)];
        double ms = i < _words.count ? word.word.start : word.word.end;
        double x = i == 0 ? -kFillEdge / 2 : i < _words.count ? word.offset : word.offset + word.bounds.size.width + kFillEdge / 2;
        if (_knotCount && ms <= _knots[_knotCount - 1].ms) {
            _knots[_knotCount - 1].x = x;
            continue;
        }
        _knots[_knotCount++] = (SGSweepKnot){ms, x, 0};
    }
    // Fritsch-Carlson slopes: capped so the cursor never runs backwards or overshoots a word.
    for (NSUInteger k = 0; k < _knotCount; k++) {
        BOOL first = k == 0, last = k + 1 == _knotCount;
        if (first && last) break;
        if (first || last) {
            _knots[k].slope = secant(_knots, first ? 0 : k - 1);
            continue;
        }
        double before = secant(_knots, k - 1), after = secant(_knots, k);
        double h0 = _knots[k].ms - _knots[k - 1].ms, h1 = _knots[k + 1].ms - _knots[k].ms;
        _knots[k].slope = MIN(MIN(2 * before, 2 * after), (before * h1 + after * h0) / (h0 + h1));
    }
}

- (CGFloat)cursorAt:(double)ms {
    if (!_knotCount) return -CGFLOAT_MAX;
    if (ms <= _knots[0].ms) return _knots[0].x;
    if (_knotCount == 1 || ms >= _knots[_knotCount - 1].ms) return _knots[_knotCount - 1].x;
    NSUInteger k = 0;
    while (ms >= _knots[k + 1].ms) k++;
    SGSweepKnot a = _knots[k], b = _knots[k + 1];
    double h = b.ms - a.ms, u = (ms - a.ms) / h, u2 = u * u, u3 = u2 * u;
    return (2 * u3 - 3 * u2 + 1) * a.x + (u3 - 2 * u2 + u) * h * a.slope
         + (3 * u2 - 2 * u3) * b.x + (u3 - u2) * h * b.slope;
}

// Eases from wherever the blur is on screen, so a line coming into focus sharpens instead of snapping.
- (void)setBlur:(CGFloat)blur {
    if (blur == _blur) return;
    id shown = [self.layer.presentationLayer valueForKeyPath:kBlurPath];
    CGFloat from = [shown isKindOfClass:NSNumber.class] ? [shown doubleValue] : _blur;
    _blur = blur;
    if (!self.layer.filters) return;
    [self.layer setValue:@(blur) forKeyPath:kBlurPath];
    CABasicAnimation *ease = [CABasicAnimation animationWithKeyPath:kBlurPath];
    ease.fromValue = @(from);
    ease.toValue = @(blur);
    ease.duration = 0.6;
    ease.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.layer addAnimation:ease forKey:@"blur"];
}

- (void)setActive:(BOOL)active {
    if (active == _active) return;
    _active = active;
    _backing.active = active;
    NSUInteger generation = ++_generation;
    if (active) {
        for (SGKaraokeWordView *word in _words) {
            [word.layer removeAllAnimations];
            [word.lit.layer removeAllAnimations];
            word.lit.alpha = 1;
            word.lit.hidden = NO;
            [word fillTo:-CGFLOAT_MAX];
            [word settle];
        }
        return;
    }
    // A sung line fades back to dim rather than dropping its fill at once, and its words sink back
    // on a spring slow enough to still be seen doing it.
    [UIView animateWithDuration:0.9 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        for (SGKaraokeWordView *word in self->_words) [word settle];
    } completion:nil];
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        for (SGKaraokeWordView *word in self->_words) word.lit.alpha = 0;
    } completion:^(BOOL finished) {
        if (generation != self->_generation) return;
        for (SGKaraokeWordView *word in self->_words) {
            [word fillTo:-CGFLOAT_MAX];
            word.lit.hidden = YES;
            word.lit.alpha = 1;
        }
    }];
}

- (void)showTime:(double)ms {
    CGFloat cursor = [self cursorAt:ms];
    for (SGKaraokeWordView *word in _words) {
        [word fillTo:cursor];
        [word floatAt:ms];
    }
    [_backing showTime:ms];   // timed on its own, so it lags the line as it is sung
}

@end

#pragma mark - the page

@interface SGKaraokeView () <UIScrollViewDelegate>
@end

@implementation SGKaraokeView {
    UIScrollView *_scroll;
    BOOL _browsing;
    CADisplayLink *_link;
    NSString *_track;
    NSArray<SGKaraokeLine *> *_lines;
    // The song is placed from its lines' heights alone; views exist for the lines in and near sight.
    NSArray<NSNumber *> *_tops;   // where each line starts in the stack
    NSMutableDictionary<NSNumber *, SGKaraokeLineView *> *_shown;   // the views there are, by line
    CGFloat _focusTop;            // the top of the line the stack is arranged around
    CGFloat _sightOffset, _sightFocus;   // what the views in sight were last chosen for
    NSInteger _sightActive;
    NSUInteger _build;   // counts the songs and widths measured, so a measurement that is late is dropped
    UIFont *_font;
    NSInteger _active;
    CGFloat _builtWidth;
    BOOL _showing;
    CAGradientLayer *_fade;
    UILabel *_credit;
    CGFloat _fontSize, _margin, _lineGap, _blurPerLine, _maxBlur;
    BOOL _compact;
    BOOL _crediting;   // the switch is read once: the page asks for the source on every frame until it has one
    double _clock;
    NSInteger _reported;
    CFTimeInterval _clockTime;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame compact:NO];
}

- (instancetype)initWithFrame:(CGRect)frame compact:(BOOL)compact {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.hidden = YES;
    _active = -1;
    _compact = compact;
    _fontSize = compact ? kCardFontSize : kFontSize;
    _margin = compact ? kCardMargin : kMargin;
    _lineGap = compact ? kCardLineGap : kLineGap;
    _blurPerLine = compact ? 0 : kBlurPerLine;
    _maxBlur = compact ? 0 : kMaxBlur;
    _shown = [NSMutableDictionary dictionary];
    _sightActive = -2;
    _fade = [CAGradientLayer layer];
    _fade.colors = @[(id)UIColor.clearColor.CGColor, (id)UIColor.whiteColor.CGColor,
                     (id)UIColor.whiteColor.CGColor, (id)UIColor.clearColor.CGColor];
    _fade.locations = @[@0, @(kEdgeFade), @(1 - kEdgeFade), @1];
    _scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scroll.layer.mask = _fade;
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _scroll.showsVerticalScrollIndicator = NO;
    _scroll.alwaysBounceVertical = YES;
    _scroll.scrollsToTop = NO;
    _scroll.delegate = self;
    [self addSubview:_scroll];
    _credit = [[UILabel alloc] initWithFrame:CGRectZero];
    _credit.font = [UIFont systemFontOfSize:kCreditSize weight:UIFontWeightSemibold];
    _credit.textColor = [UIColor colorWithWhite:1 alpha:kCreditAlpha];
    _credit.hidden = YES;
    _crediting = !compact && SGFlag(SGKeyLyricsCredit, NO);   // the card has no room to name a source
    [self addSubview:_credit];
    // A tap on the card is Spotify's, and opens the full screen page; seeking by tap is the page's.
    if (compact) self.userInteractionEnabled = NO;
    else [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)]];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(playerTransitionChanged:) name:SGPlayerTransitionNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(playerTransitionChanged:) name:SGPlayerTransitionEndedNotification object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)tapped:(UITapGestureRecognizer *)tap {
    CGPoint point = [tap locationInView:_scroll];
    for (SGKaraokeLineView *view in _shown.allValues) {
        if (!CGRectContainsPoint(CGRectInset(view.frame, -_margin, -_lineGap / 2), point)) continue;
        SGKaraokeSeek(view.line.start);
        [self followSong];
        return;
    }
}

#pragma mark - scrolling by hand

// Lines are placed for a content offset of 0, so following the song means scrolling back to 0.
// While the user browses, placement stands still and every line is sharp.
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(followSong) object:nil];
    _browsing = YES;
    for (SGKaraokeLineView *view in _shown.allValues) view.blur = 0;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self showLinesInSight];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) [self performSelector:@selector(followSong) withObject:nil afterDelay:kBrowseHold];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self performSelector:@selector(followSong) withObject:nil afterDelay:kBrowseHold];
}

- (void)followSong {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(followSong) object:nil];
    if (!_browsing) return;
    _browsing = NO;
    [UIView animateWithDuration:0.7 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self->_scroll.contentOffset = CGPointZero; } completion:nil];
    [self placeLinesAnimated:YES];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(followSong) object:nil];
        _browsing = NO;
    }
    [self scheduleLink];
}

// The player opens and closes in animations that run at 120 Hz, and while a display link asked
// for 30 to 60, the range Apple's ProMotion guide says Core Animation gives priority to, those
// animations ran rough; the player and the lyrics themselves were smooth throughout. The card's
// link now asks for 60 but takes 120, and is put down for as long as the player animates, which
// NowPlayingBar.x announces as each animation starts and again as it ends; the card holds still
// under it, where nobody sees it. The timer is for an end that is never announced.
- (void)scheduleLink {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startLink) object:nil];
    [_link invalidate];
    _link = nil;
    if (!self.window) return;
    NSTimeInterval wait = SGPlayerTransitionEnds() - CACurrentMediaTime();
    if (wait <= 0) [self startLink];
    else [self performSelector:@selector(startLink) withObject:nil afterDelay:wait + kTransitionSlack inModes:@[NSRunLoopCommonModes]];
}

- (void)startLink {
    if (!self.window || _link) return;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    // The card stays in the window behind the full screen page, so both sweep at once; the card is
    // a few lines tall and is content with 60, the page keeps the high refresh rate.
    _link.preferredFrameRateRange = _compact ? CAFrameRateRangeMake(30, 120, 60) : CAFrameRateRangeMake(80, 120, 120);
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)playerTransitionChanged:(NSNotification *)note {
    [self scheduleLink];
}

// The mask sits in the scroll view's own coordinates, which move with the content as it scrolls, so
// it is put back over the visible part on every frame, where the presentation layer says the
// content is: that holds through a drag and through the animated scroll home alike. Left where
// layout put it, it covered the first screenful of lines only, and a scroll past them showed nothing.
- (void)alignFade {
    CALayer *shown = (CALayer *)_scroll.layer.presentationLayer ?: _scroll.layer;
    CGRect frame = CGRectMake(0, shown.bounds.origin.y, self.bounds.size.width, self.bounds.size.height);
    if (CGRectEqualToRect(frame, _fade.frame)) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fade.frame = frame;
    [CATransaction commit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self alignFade];
    _scroll.contentSize = self.bounds.size;
    [_credit sizeToFit];
    _credit.frame = CGRectMake(_margin, self.bounds.size.height - _credit.bounds.size.height - kCreditBottom,
                               _credit.bounds.size.width, _credit.bounds.size.height);
    if (_lines && self.bounds.size.width != _builtWidth) [self rebuild];
}

- (void)dropLineViews {
    for (UIView *view in _shown.allValues) [view removeFromSuperview];
    [_shown removeAllObjects];
    _tops = nil;
    _sightActive = -2;
    _build++;
}

// Measures the song for the width and, once that is in, places it; Spotify's own lines stay in view
// until then, since the page shows nothing of its own before it has lines to show.
- (void)rebuild {
    [self dropLineViews];
    _active = -1;
    _browsing = NO;
    _scroll.contentOffset = CGPointZero;
    _builtWidth = self.bounds.size.width;
    CGFloat width = _builtWidth - 2 * _margin;
    if (width <= 0) return;
    _font = [UIFont systemFontOfSize:_fontSize weight:UIFontWeightBold];
    UIFont *font = _font;
    NSArray<SGKaraokeLine *> *lines = _lines;
    CGFloat gap = _lineGap;
    NSUInteger build = _build;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSArray<NSNumber *> *tops = topsOf(lines, width, font, gap);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (build != self->_build) return;   // the song or the width moved on meanwhile
            self->_tops = tops;
            [self placeLinesAnimated:NO];
        });
    });
}

// Where a line starts on the page, for the stack as it is arranged now.
- (CGFloat)topOfLine:(NSInteger)index {
    return self.bounds.size.height * kAnchor + _tops[index].doubleValue - _focusTop;
}

// The view of a line, made the first time it is asked for and placed where the stack has it.
- (SGKaraokeLineView *)viewForLine:(NSInteger)index {
    SGKaraokeLineView *view = _shown[@(index)];
    if (view || !_tops || index < 0 || index >= (NSInteger)_tops.count) return view;
    view = [[SGKaraokeLineView alloc] initWithLine:_lines[index] width:_builtWidth - 2 * _margin font:_font backing:NO blurred:_maxBlur > 0];
    [_scroll addSubview:view];
    _shown[@(index)] = view;
    [self placeLine:view at:index animated:NO];
    return view;
}

// Views for the lines just outside the visible part as well as in it, wherever that is: around the
// sung line while following the song, around wherever the page has been scrolled to while browsing.
// The ones further off are let go, so a long song costs a couple of dozen line views rather than
// one for every line, and the lines in sight are the only ones the compositor has to draw.
- (void)showLinesInSight {
    if (!_tops.count) return;
    CGFloat offset = ((CALayer *)_scroll.layer.presentationLayer ?: _scroll.layer).bounds.origin.y;
    if (offset == _sightOffset && _focusTop == _sightFocus && _active == _sightActive) return;
    _sightOffset = offset;
    _sightFocus = _focusTop;
    _sightActive = _active;
    CGFloat height = self.bounds.size.height;
    CGFloat from = offset - kSightBehind * height, to = offset + (1 + kSightAhead) * height, slack = kSightSlack * height;
    NSMutableArray<NSNumber *> *gone = [NSMutableArray array];
    for (NSNumber *key in _shown) {
        NSInteger index = key.integerValue;
        CGFloat top = [self topOfLine:index], bottom = top + _shown[key].bounds.size.height;
        if (index != _active && (bottom < from - slack || top > to + slack)) [gone addObject:key];
    }
    for (NSNumber *key in gone) {
        [_shown[key] removeFromSuperview];
        [_shown removeObjectForKey:key];
    }
    NSInteger count = (NSInteger)_tops.count;
    NSMutableArray<NSNumber *> *wanted = [NSMutableArray array];
    for (NSInteger index = 0; index < count; index++) {
        if (_shown[@(index)]) continue;
        CGFloat top = [self topOfLine:index];
        CGFloat bottom = index + 1 < count ? [self topOfLine:index + 1] - _lineGap : top + height;
        if (bottom < from || top > to) continue;
        [wanted addObject:@(index)];
    }
    // A few a frame, the nearest the middle of the visible part first, so a page scrolled by hand
    // fills in what is in view before what is not; the next frame picks up where this one left off.
    CGFloat middle = offset + height / 2;
    [wanted sortUsingComparator:^NSComparisonResult(NSNumber *a, NSNumber *b) {
        CGFloat da = fabs([self topOfLine:a.integerValue] - middle), db = fabs([self topOfLine:b.integerValue] - middle);
        return da < db ? NSOrderedAscending : da > db ? NSOrderedDescending : NSOrderedSame;
    }];
    NSUInteger made = 0;
    for (NSNumber *index in wanted) {
        if (made++ == kLinesPerFrame) {
            _sightOffset = -CGFLOAT_MAX;
            break;
        }
        [self viewForLine:index.integerValue];
    }
}

// One line's place in the stack: the anchor sits on the edge its text is aligned to, so it scales
// toward its own text, and it dims and blurs with its distance from the sung line.
- (void)placeLine:(SGKaraokeLineView *)view at:(NSInteger)index animated:(BOOL)animated {
    CGFloat height = self.bounds.size.height;
    NSInteger distance = index - _active;
    CGRect frame = CGRectMake(_margin, [self topOfLine:index], view.bounds.size.width, view.bounds.size.height);
    BOOL trailing = view.line.align == SGKaraokeAlignTrailing;
    CGPoint center = CGPointMake(trailing ? CGRectGetMaxX(frame) : _margin, CGRectGetMidY(frame));
    CGFloat scale = distance == 0 ? 1 : kDimScale;
    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
    view.blur = distance == 0 || _browsing ? 0 : MIN(_maxBlur, labs(distance) * _blurPerLine);
    BOOL near = CGRectIntersectsRect(CGRectInset(self.bounds, 0, -height / 2), frame)
             || CGRectIntersectsRect(CGRectInset(self.bounds, 0, -height / 2), view.frame);
    if (!animated || !near) {
        view.center = center;
        view.transform = transform;
        return;
    }
    NSTimeInterval delay = distance > 0 ? MIN(0.3, distance * 0.04) : 0;
    [UIView animateWithDuration:0.7 delay:delay usingSpringWithDamping:0.86 initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        view.center = center;
        view.transform = transform;
    } completion:nil];
}

// The sung line rests at the anchor and the rest stack around it; lines below it follow a beat
// later, the further down the later, as Apple Music's do.
- (void)placeLinesAnimated:(BOOL)animated {
    if (_browsing || !_tops.count) return;
    _focusTop = _tops[(NSUInteger)MAX(_active, 0)].doubleValue;
    [self showLinesInSight];
    for (NSNumber *key in _shown) [self placeLine:_shown[key] at:key.integerValue animated:animated];
    // Room to scroll until the first line or the last one reaches the anchor.
    CGFloat lastTop = _tops.lastObject.doubleValue;
    _scroll.contentInset = UIEdgeInsetsMake(_focusTop, 0, MAX(0, lastTop - _focusTop), 0);
}

- (void)creditTo:(NSString *)source {
    NSString *text = source.length && _crediting ? [NSString stringWithFormat:@"Lyrics from %@", source] : nil;
    if (text == _credit.text || [text isEqualToString:_credit.text]) return;
    _credit.text = text;
    _credit.hidden = !_showing || !text.length;
    [self setNeedsLayout];
}

- (void)syncSiblings {
    for (UIView *sibling in self.superview.subviews) {
        if (sibling != self && _showing) sibling.alpha = 0;
    }
}

- (void)setShowing:(BOOL)showing {
    if (showing == _showing) return;
    _showing = showing;
    self.hidden = !showing;
    _credit.hidden = !showing || !_credit.text.length;
    for (UIView *sibling in self.superview.subviews) {
        if (sibling != self) sibling.alpha = showing ? 0 : 1;
    }
}

// The player's position run on by the frame times the display will show and eased toward each new
// reading, so the sweep follows neither the callback's jitter nor the small jumps of the core's
// corrections. A seek or a new track is too far off to ease and is taken at once.
- (double)clockMs {
    NSInteger raw = SGKaraokePositionMs();
    CFTimeInterval shown = _link.targetTimestamp;
    BOOL running = raw != _reported;   // a paused player reports the same position every frame
    double reported = raw + (running ? (shown - CACurrentMediaTime()) * 1000 : 0);
    double predicted = _clock + (running ? (shown - _clockTime) * 1000 : 0);
    double error = reported - predicted;
    _clock = raw < 0 || fabs(error) > kClockSnapMs ? reported : predicted + error * kClockPull;
    _reported = raw;
    _clockTime = shown;
    return _clock;
}

- (void)tick {
    NSString *track = SGKaraokePlayingTrack();
    if (!(track == _track || [track isEqualToString:_track])) {
        SGLog(@"karaoke: page shows track %@, lyrics %@", track, SGKaraokeLinesForTrack(track) ? @"captured" : @"not captured yet");
        _track = track;
        _lines = nil;
        _builtWidth = 0;
        [self creditTo:nil];
        [self dropLineViews];
    }
    if (!_lines && track && (_lines = SGKaraokeLinesForTrack(track))) {
        SGLog(@"karaoke: showing %lu lines of %@", (unsigned long)_lines.count, track);
        [self setNeedsLayout];
    }
    [self setShowing:_tops != nil];
    // The source is settled a moment after the lines are, so it is asked for until it answers.
    if (_crediting && _lines && !_credit.text.length) [self creditTo:SGLyricsCreditFor(track)];
    if (!_tops) return;
    [self alignFade];

    double now = [self clockMs];
    NSInteger active = -1;
    for (NSUInteger i = 0; i < _lines.count && _lines[i].start <= now; i++) active = i;
    if (active != _active) {
        if (_active >= 0) _shown[@(_active)].active = NO;
        if (active >= 0) [self viewForLine:active].active = YES;
        BOOL jump = labs(active - _active) > 2;   // a seek, not the song moving on
        _active = active;
        [self placeLinesAnimated:!jump];
    } else {
        [self showLinesInSight];   // the page may be scrolling by hand, or springing back
    }
    if (active >= 0) [_shown[@(active)] showTime:now];
}

@end
