#import "Core/SGCore.h"
#import "SGRGlass.h"
#import "SGRTokens.h"

static const CGFloat kSymbolSize = 17, kPressScale = 0.96;
static const CGFloat kProminentMinWidth = 132, kCapsuleMinWidth = 96, kCapsuleMaxWidth = 140, kCapsulePadding = 20;
static const NSTimeInterval kTitleFade = 0.2;

typedef NS_ENUM(NSInteger, SGRGlassMode) {
    SGRGlassModeGlass,
    SGRGlassModeBlur,
    SGRGlassModeSolid,
};

static SGRGlassMode glassMode(void) {
    if (SGRReduceTransparency()) return SGRGlassModeSolid;
    if (@available(iOS 26.0, *)) return SGRGlassModeGlass;
    return SGRGlassModeBlur;
}

// The container glass shapes merge in, or a plain view where there is no glass to merge.
static UIView *newContainer(SGRGlassMode mode, CGFloat spacing) {
    if (mode == SGRGlassModeGlass) {
        if (@available(iOS 26.0, *)) {
            UIGlassContainerEffect *effect = [UIGlassContainerEffect new];
            effect.spacing = spacing;
            return [[UIVisualEffectView alloc] initWithEffect:effect];
        }
    }
    return [UIView new];
}

static UIView *contentOf(UIView *container) {
    return [container isKindOfClass:UIVisualEffectView.class] ? ((UIVisualEffectView *)container).contentView : container;
}

static UIView *newShape(SGRGlassMode mode) {
    UIView *shape;
    switch (mode) {
        case SGRGlassModeGlass:
            shape = [[UIVisualEffectView alloc] initWithEffect:SGGlassEffect()];
            break;
        case SGRGlassModeBlur:
            shape = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
            break;
        case SGRGlassModeSolid:
            shape = [UIView new];
            shape.backgroundColor = SGRSolidGlassFill();
            break;
    }
    shape.userInteractionEnabled = NO;
    return shape;
}

#pragma mark - inside a control

static char kInsideModeKey;

UIView *SGRGlassInside(UIView *control, const void *key, CGFloat side) {
    if (!control || !key) return nil;
    SGRGlassMode mode = glassMode();
    UIView *shape = objc_getAssociatedObject(control, key);
    if (shape && [objc_getAssociatedObject(shape, &kInsideModeKey) integerValue] != mode) {
        [shape removeFromSuperview];
        shape = nil;
    }
    if (!shape) {
        shape = newShape(mode);
        shape.accessibilityElementsHidden = YES;
        // Last among the control's subviews, so code of Spotify's reading its first subview still finds
        // its own; the depth puts it behind them all the same.
        shape.layer.zPosition = -1;
        shape.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                               | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        objc_setAssociatedObject(shape, &kInsideModeKey, @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(control, key, shape, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (shape.superview != control) [control addSubview:shape];
    shape.hidden = side <= 0;
    CGRect bounds = CGRectMake(0, 0, side, side);
    if (!CGRectEqualToRect(shape.bounds, bounds)) {
        shape.bounds = bounds;
        SGShapeGlass(shape, side / 2, YES);
    }
    CGPoint middle = CGPointMake(CGRectGetMidX(control.bounds), CGRectGetMidY(control.bounds));
    if (!CGPointEqualToPoint(shape.center, middle)) shape.center = middle;
    return shape;
}

#pragma mark - backing

@implementation SGRGlassBacking {
    UIView *_container;
    NSMutableArray<UIView *> *_shapes;
    SGRGlassMode _mode;
}

+ (instancetype)backingInHost:(UIView *)host key:(const void *)key {
    if (!host || !key) return nil;
    SGRGlassBacking *backing = objc_getAssociatedObject(host, key);
    if (!backing) {
        backing = [[self alloc] initWithFrame:host.bounds];
        objc_setAssociatedObject(host, key, backing, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (backing.superview != host) [host insertSubview:backing atIndex:0];
    if (!CGRectEqualToRect(backing.frame, host.bounds)) backing.frame = host.bounds;
    return backing;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    // Behind whatever the host puts in at index 0 after it, as the panes of Core/SGGlass.m are.
    self.layer.zPosition = -1;
    _shapes = [NSMutableArray array];
    _mode = -1;
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _container.frame = self.bounds;
}

// Reduce Transparency can change while the page is open; the shapes are made again for it.
- (void)rebuildIfNeeded {
    SGRGlassMode mode = glassMode();
    if (mode == _mode) return;
    _mode = mode;
    [_shapes makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_shapes removeAllObjects];
    [_container removeFromSuperview];
    _container = newContainer(mode, SGRGlassSpacing);
    _container.userInteractionEnabled = NO;
    _container.frame = self.bounds;
    [self addSubview:_container];
}

- (UIView *)newShape {
    return newShape(_mode);
}

- (void)setShapes:(NSArray<NSValue *> *)framesInHost shape:(SGRGlassShape)kind {
    [self rebuildIfNeeded];
    NSUInteger count = 0;
    for (NSValue *value in framesInHost) {
        CGRect frame = [self convertRect:value.CGRectValue fromView:self.superview];
        if (CGRectIsEmpty(frame) || CGRectIsNull(frame)) continue;
        if (kind == SGRGlassCircle) {
            CGFloat side = MIN(frame.size.width, frame.size.height);
            frame = CGRectMake(CGRectGetMidX(frame) - side / 2, CGRectGetMidY(frame) - side / 2, side, side);
        }
        while (_shapes.count <= count) {
            UIView *shape = [self newShape];
            [contentOf(_container) addSubview:shape];
            [_shapes addObject:shape];
        }
        UIView *shape = _shapes[count++];
        shape.hidden = NO;
        if (!CGRectEqualToRect(shape.frame, frame)) {
            shape.frame = frame;
            SGShapeGlass(shape, frame.size.height / 2, YES);
        }
    }
    for (NSUInteger i = count; i < _shapes.count; i++) _shapes[i].hidden = YES;
}

@end

#pragma mark - buttons

@interface SGRGlassButton ()
- (CGFloat)rowWidth;
@end

@implementation SGRGlassButton {
    NSString *_symbol;
    NSString *_title;
    BOOL _prominent;
    BOOL _circle;
    SGRGlassMode _mode;
}

+ (instancetype)circleWithSymbol:(NSString *)symbol accessibilityLabel:(NSString *)label {
    SGRGlassButton *button = [[self alloc] initWithFrame:CGRectMake(0, 0, SGRActionHeight, SGRActionHeight)];
    button->_circle = YES;
    button->_symbol = [symbol copy];
    button.accessibilityLabel = label;
    [button configure];
    return button;
}

+ (instancetype)capsuleWithSymbol:(NSString *)symbol title:(NSString *)title prominent:(BOOL)prominent {
    SGRGlassButton *button = [[self alloc] initWithFrame:CGRectMake(0, 0, kCapsuleMinWidth, SGRActionHeight)];
    button->_symbol = [symbol copy];
    button->_title = [title copy];
    button->_prominent = prominent;
    [button configure];
    return button;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _mode = -1;
    [self addTarget:self action:@selector(tapped) forControlEvents:UIControlEventPrimaryActionTriggered];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged:) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)tapped {
    if (self.onTap) self.onTap();
}

- (void)settingsChanged:(NSNotification *)note {
    [self configure];
}

// Above the Large content size the title would outgrow the 48pt button, so only the symbol is shown
// and the title stays the accessibility label.
static BOOL titleFits(void) {
    UIContentSizeCategory current = UIApplication.sharedApplication.preferredContentSizeCategory;
    return UIContentSizeCategoryCompareToCategory(current, UIContentSizeCategoryLarge) != NSOrderedDescending;
}

- (UIColor *)contentColor {
    if (_on) return SGRAccent();
    return _prominent ? UIColor.blackColor : SGRPrimary();
}

- (void)configure {
    SGRGlassMode mode = glassMode();
    UIButtonConfiguration *config = nil;
    if (mode == SGRGlassModeGlass) {
        if (@available(iOS 26.0, *)) {
            config = _prominent ? [UIButtonConfiguration prominentGlassButtonConfiguration] : [UIButtonConfiguration glassButtonConfiguration];
            if (_prominent) config.baseBackgroundColor = [UIColor colorWithWhite:0.96 alpha:1];
        }
    }
    if (!config) {
        config = [UIButtonConfiguration filledButtonConfiguration];
        config.baseBackgroundColor = _prominent ? [UIColor colorWithWhite:0.96 alpha:1] : (mode == SGRGlassModeBlur ? [UIColor colorWithWhite:1 alpha:0.12] : SGRSolidGlassFill());
        if (mode == SGRGlassModeBlur && !_prominent) {
            config.background.customView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
        }
    }
    _mode = mode;
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.baseForegroundColor = [self contentColor];
    config.image = _symbol ? [UIImage systemImageNamed:_symbol] : nil;
    config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:kSymbolSize weight:UIImageSymbolWeightSemibold];
    config.imagePadding = 6;
    if (_circle) {
        config.contentInsets = NSDirectionalEdgeInsetsZero;
    } else {
        config.contentInsets = NSDirectionalEdgeInsetsMake(0, kCapsulePadding, 0, kCapsulePadding);
        BOOL showTitle = _title.length && (titleFits() || !_symbol);
        UIFont *font = SGRFont(UIFontTextStyleBody, UIFontWeightSemibold, UIContentSizeCategoryLarge);
        config.attributedTitle = showTitle ? [[NSAttributedString alloc] initWithString:_title attributes:@{NSFontAttributeName: font}] : nil;
        self.accessibilityLabel = _title;
    }
    self.showsLargeContentViewer = YES;
    self.largeContentTitle = _title ?: self.accessibilityLabel;
    self.largeContentImage = config.image;
    self.configuration = config;
}

- (void)setOn:(BOOL)on {
    self.accessibilityValue = on ? @"On" : @"Off";
    if (on == _on) return;
    _on = on;
    [self configure];
}

- (void)setSymbol:(NSString *)symbol animated:(BOOL)animated {
    if (!symbol || [symbol isEqualToString:_symbol]) return;
    _symbol = [symbol copy];
    if (@available(iOS 17.0, *)) self.symbolAnimationEnabled = animated && !SGRReduceMotion() && self.window;
    [self configure];
}

- (void)setTitle:(NSString *)title animated:(BOOL)animated {
    if (!title || [title isEqualToString:_title]) return;
    _title = [title copy];
    if (!animated || !self.window) {
        [self configure];
        return;
    }
    [UIView transitionWithView:self duration:kTitleFade options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction animations:^{
        [self configure];
    } completion:nil];
}

// UIKit's glass buttons answer a press themselves; the stand-ins get the Kit's press spring.
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (_mode == SGRGlassModeGlass) return;
    SGRAnimate(SGRMotionPress, ^{
        self.transform = highlighted ? CGAffineTransformMakeScale(kPressScale, kPressScale) : CGAffineTransformIdentity;
    }, nil);
}

// The width the action row gives the button.
- (CGFloat)rowWidth {
    if (_circle) return SGRActionHeight;
    CGFloat natural = ceil([self sizeThatFits:CGSizeMake(CGFLOAT_MAX, SGRActionHeight)].width);
    if (_prominent) return MAX(kProminentMinWidth, natural);
    return MIN(kCapsuleMaxWidth, MAX(kCapsuleMinWidth, natural));
}

@end

#pragma mark - action row

@implementation SGRActionRow {
    UIView *_container;
    SGRGlassMode _mode;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _mode = -1;
    [self rebuildIfNeeded];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(transparencyChanged:) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)transparencyChanged:(NSNotification *)note {
    [self rebuildIfNeeded];
    [self setNeedsLayout];
}

- (void)rebuildIfNeeded {
    SGRGlassMode mode = glassMode();
    if (mode == _mode) return;
    _mode = mode;
    [_container removeFromSuperview];
    _container = newContainer(mode, SGRActionSpacing);
    [self addSubview:_container];
    for (UIButton *button in _buttons) [contentOf(_container) addSubview:button];
}

- (void)setButtons:(NSArray<UIButton *> *)buttons {
    for (UIButton *button in _buttons) {
        if (![buttons containsObject:button]) [button removeFromSuperview];
    }
    _buttons = [buttons copy];
    for (UIButton *button in _buttons) [contentOf(_container) addSubview:button];
    [self setNeedsLayout];
}

static CGFloat widthInRow(UIButton *button) {
    if ([button isKindOfClass:SGRGlassButton.class]) return [(SGRGlassButton *)button rowWidth];
    CGFloat natural = ceil([button sizeThatFits:CGSizeMake(CGFLOAT_MAX, SGRActionHeight)].width);
    return MIN(kCapsuleMaxWidth, MAX(kCapsuleMinWidth, natural));
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat total = 0;
    for (UIButton *button in _buttons) total += widthInRow(button);
    if (_buttons.count > 1) total += SGRActionSpacing * (_buttons.count - 1);
    return CGSizeMake(total, SGRActionHeight);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize row = [self sizeThatFits:self.bounds.size];
    CGSize bounds = self.bounds.size;
    _container.frame = CGRectMake(floor((bounds.width - row.width) / 2), floor((bounds.height - row.height) / 2), row.width, row.height);
    CGFloat x = 0;
    for (UIButton *button in _buttons) {
        CGFloat width = widthInRow(button);
        button.bounds = CGRectMake(0, 0, width, SGRActionHeight);
        button.center = CGPointMake(x + width / 2, SGRActionHeight / 2);
        x += width + SGRActionSpacing;
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == _container || hit == contentOf(_container)) ? nil : hit;
}

@end
