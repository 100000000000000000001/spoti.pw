#import <objc/message.h>
#import <CoreText/SFNTLayoutTypes.h>
#import "Core/SGCore.h"
#import "SGRRestyle.h"
#import "SGRTokens.h"

static char kPlateKey, kHeaderKey, kObservationsKey, kPageURIKey, kClearRootKey;

@interface SGRWeakBox : NSObject
@property (nonatomic, weak) id value;
@end

@implementation SGRWeakBox
@end

#pragma mark - instance subclasses

// A Swift class can lose its metadata when the runtime makes a subclass of it, and an instance KVO
// already swapped the class of would be swapped back when its last observer goes; neither is subclassed.
static BOOL subclassable(Class cls) {
    const char *name = class_getName(cls);
    return strncmp(name, "_Tt", 3) != 0 && !strchr(name, '.') && strncmp(name, "NSKVONotifying_", 15) != 0;
}

// The class `prefix` + the instance's class, made once, answering `class` with the original so
// isKindOfClass:, NSStringFromClass and the tree dumps see what Spotify made.
static Class instanceSubclass(Class original, const char *prefix, void (^install)(Class subclass, Class original)) {
    NSString *name = [NSString stringWithFormat:@"%s%s", prefix, class_getName(original)];
    Class subclass = objc_getClass(name.UTF8String);
    if (subclass) return subclass;
    subclass = objc_allocateClassPair(original, name.UTF8String, 0);
    if (!subclass) return Nil;
    install(subclass, original);
    class_addMethod(subclass, @selector(class), imp_implementationWithBlock(^Class(id self) { return original; }), "#@:");
    objc_registerClassPair(subclass);
    return subclass;
}

// Moves the view into the subclass unless it is already in it; NO when the view cannot be subclassed.
static BOOL adopt(UIView *view, const char *prefix, void (^install)(Class subclass, Class original)) {
    Class current = object_getClass(view);
    if (strncmp(class_getName(current), prefix, strlen(prefix)) == 0) return YES;
    if (!subclassable(current)) return NO;
    Class subclass = instanceSubclass(current, prefix, install);
    if (!subclass) return NO;
    object_setClass(view, subclass);
    return YES;
}

static void addOverride(Class subclass, Class original, SEL selector, id block) {
    Method method = class_getInstanceMethod(original, selector);
    if (method) class_addMethod(subclass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method));
}

#pragma mark - views

void SGRSuppress(UIView *view) {
    if (!view) return;
    BOOL kept = adopt(view, "SGRSuppressed_", ^(Class subclass, Class original) {
        addOverride(subclass, original, @selector(setAlpha:), ^(UIView *self, CGFloat alpha) {
            struct objc_super parent = {self, original};
            ((void (*)(struct objc_super *, SEL, CGFloat))objc_msgSendSuper)(&parent, @selector(setAlpha:), 0);
        });
        addOverride(subclass, original, @selector(setUserInteractionEnabled:), ^(UIView *self, BOOL enabled) {
            struct objc_super parent = {self, original};
            ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&parent, @selector(setUserInteractionEnabled:), NO);
        });
    });
    if (!kept) {
        static NSMutableSet<NSString *> *logged;
        if (!logged) logged = [NSMutableSet set];
        NSString *name = NSStringFromClass(object_getClass(view));
        if (![logged containsObject:name]) {
            [logged addObject:name];
            SGLog(@"redesign kit: %@ cannot keep being suppressed, set once per call", name);
        }
    }
    view.alpha = 0;
    view.userInteractionEnabled = NO;
    view.accessibilityElementsHidden = YES;
}

static BOOL hasMonospacedDigits(UIFont *font) {
    for (NSDictionary *setting in font.fontDescriptor.fontAttributes[UIFontDescriptorFeatureSettingsAttribute]) {
        if ([setting[UIFontFeatureTypeIdentifierKey] integerValue] == kNumberSpacingType
            && [setting[UIFontFeatureSelectorIdentifierKey] integerValue] == kMonospacedNumbersSelector) return YES;
    }
    return NO;
}

static void applyMonospaced(UILabel *label, Class original) {
    NSAttributedString *text = label.attributedText;
    struct objc_super parent = {label, original};
    if (!text.length) {
        UIFont *font = label.font;
        if (font && !hasMonospacedDigits(font)) {
            ((void (*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&parent, @selector(setFont:), SGRMonospacedDigitsFont(font));
        }
        return;
    }
    __block NSMutableAttributedString *mapped = nil;
    [text enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, text.length) options:0 usingBlock:^(UIFont *font, NSRange range, BOOL *stop) {
        if (!font || hasMonospacedDigits(font)) return;
        if (!mapped) mapped = [text mutableCopy];
        [mapped addAttribute:NSFontAttributeName value:SGRMonospacedDigitsFont(font) range:range];
    }];
    if (mapped) ((void (*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&parent, @selector(setAttributedText:), mapped);
}

// Spotify's setters run first; what they left is then given the feature through the original class's
// own setters. UILabel may set one property through another, so a pass started inside a pass is
// skipped rather than trusted to settle.
static BOOL sg_keepingMonospaced = NO;

static void keepMonospaced(UILabel *label, Class original) {
    if (sg_keepingMonospaced) return;
    sg_keepingMonospaced = YES;
    applyMonospaced(label, original);
    sg_keepingMonospaced = NO;
}

void SGRMonospacedDigits(UILabel *label) {
    if (![label isKindOfClass:UILabel.class]) return;
    BOOL kept = adopt(label, "SGRMonospaced_", ^(Class subclass, Class original) {
        for (NSString *name in @[@"setText:", @"setAttributedText:", @"setFont:"]) {
            SEL selector = NSSelectorFromString(name);
            addOverride(subclass, original, selector, ^(UILabel *self, id value) {
                struct objc_super parent = {self, original};
                ((void (*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&parent, selector, value);
                keepMonospaced(self, original);
            });
        }
    });
    Class original = kept ? class_getSuperclass(object_getClass(label)) : object_getClass(label);
    keepMonospaced(label, original);
}

// An identifier ending in * matches by prefix, for Spotify's ids that carry an entity after a dash.
static BOOL identifierMatches(NSString *identifier, NSString *wanted) {
    if (!identifier) return NO;
    if ([wanted hasSuffix:@"*"]) return [identifier hasPrefix:[wanted substringToIndex:wanted.length - 1]];
    return [identifier isEqualToString:wanted];
}

static UIView *findIdentifier(UIView *view, NSString *identifier) {
    if (identifierMatches(view.accessibilityIdentifier, identifier)) return view;
    for (UIView *sub in view.subviews) {
        UIView *found = findIdentifier(sub, identifier);
        if (found) return found;
    }
    return nil;
}

UIView *SGRFindByIdentifier(UIView *root, NSString *identifier, const void *cacheKey) {
    if (!root || !identifier.length) return nil;
    SGRWeakBox *box = cacheKey ? objc_getAssociatedObject(root, cacheKey) : nil;
    UIView *cached = box.value;
    if (cached && identifierMatches(cached.accessibilityIdentifier, identifier) && [cached isDescendantOfView:root]) return cached;
    UIView *found = findIdentifier(root, identifier);
    if (found && cacheKey) {
        if (!box) {
            box = [SGRWeakBox new];
            objc_setAssociatedObject(root, cacheKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        box.value = found;
    }
    return found;
}

@implementation SGRShadowPlate {
    CGRect _pathBounds;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    _cornerRadius = SGRRadiusArtwork;
    _pathBounds = CGRectNull;
    CALayer *layer = self.layer;
    layer.shadowColor = UIColor.blackColor.CGColor;
    layer.shadowOpacity = 0.45;
    layer.shadowRadius = 32;
    layer.shadowOffset = CGSizeMake(0, 12);
    return self;
}

- (void)setCornerRadius:(CGFloat)radius {
    _cornerRadius = radius;
    _pathBounds = CGRectNull;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    if (CGRectEqualToRect(bounds, _pathBounds)) return;
    _pathBounds = bounds;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:_cornerRadius].CGPath;
    [CATransaction commit];
}

@end

SGRShadowPlate *SGRShadowPlateIn(UIView *host, const void *key) {
    if (!host) return nil;
    const void *slot = key ?: &kPlateKey;
    SGRShadowPlate *plate = objc_getAssociatedObject(host, slot);
    if (!plate) {
        plate = [[SGRShadowPlate alloc] initWithFrame:host.bounds];
        objc_setAssociatedObject(host, slot, plate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (plate.superview != host) [host insertSubview:plate atIndex:0];
    return plate;
}

static BOOL isOpaqueRGB(UIColor *color, CGFloat red, CGFloat green, CGFloat blue) {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return NO;
    return a > 0.99 && fabs(r - red) < 0.01 && fabs(g - green) < 0.01 && fabs(b - blue) < 0.01;
}

void SGRStyleSpotifyCell(UIView *content) {
    if (!content) return;
    static Class divider;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ divider = NSClassFromString(@"_TtCCE16Encore_LayoutKitO16EncoreFoundation6Encore7ListRow7Divider"); });
    UIColor *secondary = SGRSecondary();
    const CGFloat grey = 0xB3 / 255.0;
    SGForEachView(content, ^(UIView *view) {
        if (SGIsBaseSurface(view.layer.backgroundColor)) view.layer.backgroundColor = NULL;
        if ([view isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)view;
            if (isOpaqueRGB(label.textColor, grey, grey, grey)) label.textColor = secondary;
        } else if (divider && [view isKindOfClass:divider]) {
            if (view.alpha != 0) view.alpha = 0;
        } else if ([view isKindOfClass:UIImageView.class]) {
            CGSize size = view.bounds.size;
            if (size.width < 40 || fabs(size.width - size.height) > 1) return;
            CGFloat radius = size.width <= 64 ? SGRRadiusThumb : SGRRadiusCover;
            if (view.layer.cornerRadius == radius) return;
            view.layer.cornerRadius = radius;
            view.layer.cornerCurve = kCACornerCurveContinuous;
            view.clipsToBounds = YES;
        }
    });
}

@implementation SGRSectionHeader {
    UILabel *_label;
    UIImageView *_chevron;
    __weak UIControl *_target;
}

+ (instancetype)headerInCell:(UICollectionViewCell *)cell title:(NSString *)title target:(UIControl *)target {
    UIView *content = cell.contentView;
    if (!content) return nil;
    SGRSectionHeader *header = objc_getAssociatedObject(cell, &kHeaderKey);
    if (!header) {
        header = [[SGRSectionHeader alloc] initWithFrame:content.bounds];
        objc_setAssociatedObject(cell, &kHeaderKey, header, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (content.subviews.lastObject != header) [content addSubview:header];
    header.frame = content.bounds;
    [header setTitle:title target:target];
    return header;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _label = [UILabel new];
    _label.textColor = SGRPrimary();
    [self addSubview:_label];
    _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    _chevron.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
    _chevron.tintColor = SGRSecondary();
    [_chevron sizeToFit];
    [self addSubview:_chevron];
    self.isAccessibilityElement = YES;
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)]];
    [self applyFont];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(contentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)applyFont {
    _label.font = SGRFont(UIFontTextStyleTitle2, UIFontWeightBold, UIContentSizeCategoryExtraExtraExtraLarge);
}

- (void)contentSizeChanged:(NSNotification *)note {
    [self applyFont];
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title target:(UIControl *)target {
    _target = target;
    // Without a target the touches go to Spotify's cell as they would without the header.
    self.userInteractionEnabled = target != nil;
    _chevron.hidden = target == nil;
    self.accessibilityLabel = title;
    self.accessibilityTraits = target ? UIAccessibilityTraitHeader | UIAccessibilityTraitButton : UIAccessibilityTraitHeader;
    if (![title isEqualToString:_label.text]) {
        _label.text = title;
        [self setNeedsLayout];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width, lineHeight = ceil(_label.font.lineHeight);
    CGFloat room = MAX(0, width - 2 * SGRSideMargin - (_chevron.hidden ? 0 : _chevron.bounds.size.width + 6));
    CGFloat textWidth = MIN(room, ceil([_label sizeThatFits:CGSizeMake(CGFLOAT_MAX, lineHeight)].width));
    _label.frame = CGRectMake(SGRSideMargin, 24, textWidth, lineHeight);
    _chevron.center = CGPointMake(SGRSideMargin + textWidth + 6 + _chevron.bounds.size.width / 2, CGRectGetMidY(_label.frame));
}

- (void)tapped {
    UIControl *target = _target;
    if (target) SGRFire(target);
}

- (BOOL)accessibilityActivate {
    UIControl *target = _target;
    return target && SGRFire(target);
}

@end

#pragma mark - Spotify's controls and pages

BOOL SGRFire(UIControl *control) {
    if (![control isKindOfClass:UIControl.class]) return NO;
    __block UIControlEvents registered = control.allControlEvents;
    [control enumerateEventHandlers:^(UIAction *action, id target, SEL selector, UIControlEvents events, BOOL *stop) {
        registered |= events;
    }];
    UIControlEvents fire = (registered & UIControlEventPrimaryActionTriggered) ? UIControlEventPrimaryActionTriggered
                         : (registered & UIControlEventTouchUpInside) ? UIControlEventTouchUpInside : 0;
    static NSMutableSet<NSString *> *logged;
    if (!logged) logged = [NSMutableSet set];
    NSString *name = NSStringFromClass(control.class);
    if (![logged containsObject:name]) {
        [logged addObject:name];
        SGLog(@"redesign kit: %@ fires %@ (events 0x%lx)", name, fire == UIControlEventPrimaryActionTriggered ? @"its primary action" : fire ? @"touch up inside" : @"nothing", (unsigned long)registered);
    }
    if (!fire) return NO;
    [control sendActionsForControlEvents:fire];
    return YES;
}

@interface SGROffsetObservation ()
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, weak) id owner;
@property (nonatomic, copy) void (^changed)(id owner, CGPoint offset);
@end

@implementation SGROffsetObservation

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    id owner = self.owner;
    UIScrollView *scrollView = self.scrollView;
    if (!owner || !scrollView) {
        [self invalidate];
        return;
    }
    if (self.changed) self.changed(owner, scrollView.contentOffset);
}

// A scroll view that went first took its observers with it (KVO lets go at the end of dealloc for a
// property it notifies about itself, iOS 11 on), so only a live one is asked to remove this.
- (void)invalidate {
    UIScrollView *scrollView = self.scrollView;
    self.scrollView = nil;
    self.changed = nil;
    if (!scrollView) return;
    @try {
        [scrollView removeObserver:self forKeyPath:@"contentOffset" context:&kObservationsKey];
    } @catch (NSException *exception) {
        SGLog(@"redesign kit: offset observation was already gone (%@)", exception.reason);
    }
}

- (void)dealloc {
    [self invalidate];
}

@end

SGROffsetObservation *SGRObserveOffset(UIScrollView *scrollView, id owner, void (^changed)(id owner, CGPoint offset)) {
    if (!scrollView || !owner || !changed) return nil;
    SGROffsetObservation *observation = [SGROffsetObservation new];
    observation.scrollView = scrollView;
    observation.owner = owner;
    observation.changed = changed;
    NSMutableArray *kept = objc_getAssociatedObject(owner, &kObservationsKey);
    if (!kept) {
        kept = [NSMutableArray array];
        objc_setAssociatedObject(owner, &kObservationsKey, kept, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [kept addObject:observation];
    [scrollView addObserver:observation forKeyPath:@"contentOffset" options:0 context:&kObservationsKey];
    return observation;
}

@protocol SGRPageController
- (id)spt_pageURI;
@end

NSURL *SGRPageURI(UIView *view) {
    if (!view) return nil;
    NSURL *cached = objc_getAssociatedObject(view, &kPageURIKey);
    if (cached) return cached;
    for (UIResponder *responder = view; responder; responder = responder.nextResponder) {
        if (![responder isKindOfClass:UIViewController.class] || ![responder respondsToSelector:@selector(spt_pageURI)]) continue;
        id uri = [(id<SGRPageController>)responder spt_pageURI];
        NSURL *url = [uri isKindOfClass:NSURL.class] ? uri : [uri isKindOfClass:NSString.class] ? [NSURL URLWithString:uri] : nil;
        if (!url) continue;
        objc_setAssociatedObject(view, &kPageURIKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return url;
    }
    return nil;
}

#pragma mark - repaint

static BOOL sg_clearRoots = NO;

void SGRRegisterClearRoot(UIView *root) {
    if (!root || objc_getAssociatedObject(root, &kClearRootKey)) return;
    objc_setAssociatedObject(root, &kClearRootKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sg_clearRoots = YES;
    SGForEachView(root, ^(UIView *view) {
        if (!SGKeepsColor(view) && SGIsBaseSurface(view.layer.backgroundColor) && SGRInsideClearRoot(view)) view.layer.backgroundColor = NULL;
    });
}

BOOL SGRHasClearRoots(void) {
    return sg_clearRoots;
}

BOOL SGRInsideClearRoot(UIView *view) {
    if (!sg_clearRoots) return NO;
    for (UIView *v = view; v; v = v.superview) {
        if ([v isKindOfClass:UIVisualEffectView.class]) return NO;
        if (objc_getAssociatedObject(v, &kClearRootKey)) return YES;
    }
    return NO;
}
