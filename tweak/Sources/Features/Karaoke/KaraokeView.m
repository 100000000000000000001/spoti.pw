#import "Core/SGCore.h"
#import "Karaoke.h"

static const CGFloat kFontSize = 30, kMargin = 24, kLineGap = 24, kRowTighten = 2;
static const CGFloat kDimAlpha = 0.3, kFillEdge = 18, kLift = 2.5;
static const CGFloat kAnchor = 0.28;   // where the sung line rests, as a share of the height
static const CGFloat kEdgeFade = 0.1;  // the lines fade out over this share at the top and bottom
static const CGFloat kBlurPerLine = 1.4, kMaxBlur = 6;
static const NSTimeInterval kBrowseHold = 3;   // after scrolling by hand, how long until it follows the song again

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
@property (nonatomic) CGFloat progress;
@end

@implementation SGKaraokeWordView {
    CAGradientLayer *_fill;
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
    _progress = -1;
    self.progress = 0;
    return self;
}

// The mask is as wide as the word plus its edge and starts fully left of it, so 0 lights nothing.
- (void)setProgress:(CGFloat)progress {
    if (progress == _progress) return;
    _progress = progress;
    CGFloat width = self.bounds.size.width + kFillEdge, height = self.bounds.size.height;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fill.frame = CGRectMake(progress * width - width, -height / 2, width, height * 2);
    [CATransaction commit];
    self.transform = CGAffineTransformMakeTranslation(0, -kLift * MIN(1, progress * 2));
}

@end

#pragma mark - a line

@interface SGKaraokeLineView : UIView
@property (nonatomic, readonly) SGKaraokeLine *line;
@property (nonatomic) BOOL active;
@property (nonatomic) CGFloat blur;
- (void)showTime:(NSInteger)ms;
@end

@implementation SGKaraokeLineView {
    NSArray<SGKaraokeWordView *> *_words;
    NSUInteger _generation;
}

- (instancetype)initWithLine:(SGKaraokeLine *)line width:(CGFloat)width font:(UIFont *)font {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _line = line;
    CGFloat space = ceil([@" " sizeWithAttributes:@{NSFontAttributeName: font}].width);
    CGFloat row = ceil(font.lineHeight) - kRowTighten, x = 0, y = 0;
    NSMutableArray<SGKaraokeWordView *> *words = [NSMutableArray array];
    for (SGKaraokeWord *word in line.words) {
        SGKaraokeWordView *view = [[SGKaraokeWordView alloc] initWithWord:word font:font];
        CGSize size = view.bounds.size;
        if (x > 0 && x + size.width > width) {
            x = 0;
            y += row;
        }
        view.center = CGPointMake(x + size.width / 2, y + size.height / 2);
        x += size.width + space;
        [self addSubview:view];
        [words addObject:view];
    }
    _words = words;
    self.frame = CGRectMake(0, 0, width, y + ceil(font.lineHeight));

    CAFilter *blur = [NSClassFromString(@"CAFilter") filterWithType:@"gaussianBlur"];
    if (blur) self.layer.filters = @[blur];
    return self;
}

- (void)setBlur:(CGFloat)blur {
    if (blur == _blur) return;
    _blur = blur;
    if (self.layer.filters) [self.layer setValue:@(blur) forKeyPath:@"filters.gaussianBlur.inputRadius"];
}

- (void)setActive:(BOOL)active {
    if (active == _active) return;
    _active = active;
    NSUInteger generation = ++_generation;
    if (active) {
        for (SGKaraokeWordView *word in _words) {
            [word.lit.layer removeAllAnimations];
            word.lit.alpha = 1;
            word.progress = 0;
        }
        return;
    }
    // A sung line fades back to dim rather than dropping its fill at once.
    [UIView animateWithDuration:0.4 animations:^{
        for (SGKaraokeWordView *word in self->_words) {
            word.lit.alpha = 0;
            word.transform = CGAffineTransformIdentity;
        }
    } completion:^(BOOL finished) {
        if (generation != self->_generation) return;
        for (SGKaraokeWordView *word in self->_words) {
            word.progress = 0;
            word.lit.alpha = 1;
        }
    }];
}

- (void)showTime:(NSInteger)ms {
    for (SGKaraokeWordView *word in _words) {
        NSInteger start = word.word.start, end = word.word.end;
        CGFloat progress = end > start ? (CGFloat)(ms - start) / (end - start) : (ms >= end ? 1 : 0);
        word.progress = MAX(0, MIN(1, progress));
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
        view.blur = distance == 0 ? 0 : MIN(kMaxBlur, labs(distance) * kBlurPerLine);
        BOOL near = CGRectIntersectsRect(CGRectInset(self.bounds, 0, -height / 2), frame)
                 || CGRectIntersectsRect(CGRectInset(self.bounds, 0, -height / 2), view.frame);
        if (!animated || !near) {
            view.frame = frame;
            continue;
        }
        NSTimeInterval delay = distance > 0 ? MIN(0.3, distance * 0.04) : 0;
        [UIView animateWithDuration:0.7 delay:delay usingSpringWithDamping:0.86 initialSpringVelocity:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{ view.frame = frame; } completion:nil];
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

    NSInteger now = SGKaraokePositionMs(), active = -1;
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
