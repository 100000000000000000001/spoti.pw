#import "Core/SGCore.h"
#import "Karaoke.h"

static const CGFloat kFontSize = 30, kMargin = 24, kLineGap = 24, kRowTighten = 2;
static const CGFloat kDimAlpha = 0.3, kFillEdge = 22, kLift = 2.5, kDimScale = 0.97;
static const CGFloat kAnchor = 0.28;   // where the sung line rests, as a share of the height
static const CGFloat kEdgeFade = 0.1;  // the lines fade out over this share at the top and bottom
static const CGFloat kBlurPerLine = 1.4, kMaxBlur = 6;
static const NSTimeInterval kBrowseHold = 3;   // after scrolling by hand, how long until it follows the song again
static const double kFloatMinMs = 700, kFloatLeadMs = 80;   // a short word still floats up this slowly
static const double kClockSnapMs = 250, kClockPull = 0.08;
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
}

- (instancetype)initWithLine:(SGKaraokeLine *)line width:(CGFloat)width font:(UIFont *)font {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _line = line;
    CGFloat space = ceil([@" " sizeWithAttributes:@{NSFontAttributeName: font}].width);
    CGFloat row = ceil(font.lineHeight) - kRowTighten, x = 0, y = 0, offset = 0;
    NSMutableArray<SGKaraokeWordView *> *words = [NSMutableArray array];
    for (SGKaraokeWord *word in line.words) {
        SGKaraokeWordView *view = [[SGKaraokeWordView alloc] initWithWord:word font:font];
        CGSize size = view.bounds.size;
        if (x > 0 && x + size.width > width) {
            x = 0;
            y += row;
        }
        view.center = CGPointMake(x + size.width / 2, y + size.height / 2);
        view.offset = offset;
        x += size.width + space;
        offset += size.width + space;
        [self addSubview:view];
        [words addObject:view];
    }
    _words = words;
    self.frame = CGRectMake(0, 0, width, y + ceil(font.lineHeight));
    // Scales toward its left edge, where the text is aligned.
    self.layer.anchorPoint = CGPointMake(0, 0.5);
    [self buildSweep];

    CAFilter *blur = [NSClassFromString(@"CAFilter") filterWithType:@"gaussianBlur"];
    if (blur) self.layer.filters = @[blur];
    return self;
}

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
    NSUInteger generation = ++_generation;
    if (active) {
        for (SGKaraokeWordView *word in _words) {
            [word.layer removeAllAnimations];
            [word.lit.layer removeAllAnimations];
            word.lit.alpha = 1;
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
    NSArray<SGKaraokeLineView *> *_lineViews;
    NSInteger _active;
    CGFloat _builtWidth;
    BOOL _showing;
    CAGradientLayer *_fade;
    double _clock;
    NSInteger _reported;
    CFTimeInterval _clockTime;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.hidden = YES;
    _active = -1;
    _fade = [CAGradientLayer layer];
    _fade.colors = @[(id)UIColor.clearColor.CGColor, (id)UIColor.whiteColor.CGColor,
                     (id)UIColor.whiteColor.CGColor, (id)UIColor.clearColor.CGColor];
    _fade.locations = @[@0, @(kEdgeFade), @(1 - kEdgeFade), @1];
    self.layer.mask = _fade;
    _scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _scroll.showsVerticalScrollIndicator = NO;
    _scroll.alwaysBounceVertical = YES;
    _scroll.scrollsToTop = NO;
    _scroll.delegate = self;
    [self addSubview:_scroll];
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)]];
    return self;
}

- (void)tapped:(UITapGestureRecognizer *)tap {
    CGPoint point = [tap locationInView:_scroll];
    for (SGKaraokeLineView *view in _lineViews) {
        if (!CGRectContainsPoint(CGRectInset(view.frame, -kMargin, -kLineGap / 2), point)) continue;
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
    for (SGKaraokeLineView *view in _lineViews) view.blur = 0;
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
    [_link invalidate];
    _link = nil;
    if (!self.window) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(followSong) object:nil];
        _browsing = NO;
        return;
    }
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    _link.preferredFrameRateRange = CAFrameRateRangeMake(80, 120, 120);
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fade.frame = self.bounds;
    [CATransaction commit];
    _scroll.contentSize = self.bounds.size;
    if (_lines && self.bounds.size.width != _builtWidth) [self rebuild];
}

- (void)rebuild {
    for (UIView *view in _lineViews) [view removeFromSuperview];
    _lineViews = nil;
    _active = -1;
    _browsing = NO;
    _scroll.contentOffset = CGPointZero;
    _builtWidth = self.bounds.size.width;
    CGFloat width = _builtWidth - 2 * kMargin;
    if (width <= 0) return;
    UIFont *font = [UIFont systemFontOfSize:kFontSize weight:UIFontWeightBold];
    NSMutableArray<SGKaraokeLineView *> *views = [NSMutableArray array];
    for (SGKaraokeLine *line in _lines) {
        SGKaraokeLineView *view = [[SGKaraokeLineView alloc] initWithLine:line width:width font:font];
        [_scroll addSubview:view];
        [views addObject:view];
    }
    _lineViews = views;
    [self placeLinesAnimated:NO];
}

// The sung line rests at the anchor and the rest stack around it; lines below it follow a beat
// later, the further down the later, as Apple Music's do.
- (void)placeLinesAnimated:(BOOL)animated {
    if (_browsing) return;
    NSInteger focus = MAX(_active, 0);
    CGFloat height = self.bounds.size.height, top = 0, focusTop = 0;
    NSMutableArray<NSNumber *> *tops = [NSMutableArray array];
    for (NSUInteger i = 0; i < _lineViews.count; i++) {
        if ((NSInteger)i == focus) focusTop = top;
        [tops addObject:@(top)];
        top += _lineViews[i].bounds.size.height + kLineGap;
    }
    for (NSUInteger i = 0; i < _lineViews.count; i++) {
        SGKaraokeLineView *view = _lineViews[i];
        NSInteger distance = (NSInteger)i - _active;
        CGFloat y = height * kAnchor + tops[i].doubleValue - focusTop;
        CGRect frame = CGRectMake(kMargin, y, view.bounds.size.width, view.bounds.size.height);
        CGPoint center = CGPointMake(kMargin, CGRectGetMidY(frame));
        CGFloat scale = distance == 0 ? 1 : kDimScale;
        CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
        view.blur = distance == 0 ? 0 : MIN(kMaxBlur, labs(distance) * kBlurPerLine);
        BOOL near = CGRectIntersectsRect(CGRectInset(self.bounds, 0, -height / 2), frame)
                 || CGRectIntersectsRect(CGRectInset(self.bounds, 0, -height / 2), view.frame);
        if (!animated || !near) {
            view.center = center;
            view.transform = transform;
            continue;
        }
        NSTimeInterval delay = distance > 0 ? MIN(0.3, distance * 0.04) : 0;
        [UIView animateWithDuration:0.7 delay:delay usingSpringWithDamping:0.86 initialSpringVelocity:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.center = center;
            view.transform = transform;
        } completion:nil];
    }
    // Room to scroll until the first line or the last one reaches the anchor.
    CGFloat lastTop = tops.lastObject.doubleValue;
    _scroll.contentInset = UIEdgeInsetsMake(focusTop, 0, MAX(0, lastTop - focusTop), 0);
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
        for (UIView *view in _lineViews) [view removeFromSuperview];
        _lineViews = nil;
    }
    if (!_lines && track && (_lines = SGKaraokeLinesForTrack(track))) {
        SGLog(@"karaoke: showing %lu lines of %@", (unsigned long)_lines.count, track);
        [self setNeedsLayout];
    }
    [self setShowing:_lines != nil];
    if (!_lineViews) return;

    double now = [self clockMs];
    NSInteger active = -1;
    for (NSUInteger i = 0; i < _lines.count && _lines[i].start <= now; i++) active = i;
    if (active != _active) {
        if (_active >= 0 && _active < (NSInteger)_lineViews.count) _lineViews[_active].active = NO;
        if (active >= 0) _lineViews[active].active = YES;
        BOOL jump = labs(active - _active) > 2;   // a seek, not the song moving on
        _active = active;
        [self placeLinesAnimated:!jump];
    }
    if (active >= 0) [_lineViews[active] showTime:now];
}

@end
