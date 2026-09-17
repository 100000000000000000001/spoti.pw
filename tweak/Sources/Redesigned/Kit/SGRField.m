#import "Core/SGCore.h"
#import "SGRField.h"
#import "SGRPalette.h"
#import "SGRTokens.h"

NSNotificationName const SGRFieldColorDidChangeNotification = @"spotifyglass.redesign.fieldColorDidChange";

static const CGFloat kFallbackHeight = 874;   // a window-less field sizes for an iPhone 17 Pro

static CGFloat windowHeight(UIView *view) {
    CGFloat height = view.window.bounds.size.height;
    return height > 0 ? height : kFallbackHeight;
}

// The field paints on sublayers of its own rather than on the view's layer: a repaint hook only clears
// the paint of a view's own layer, so the neutral colour cannot be taken for Spotify's base surface.
static NSDictionary *noActions(void) {
    static NSDictionary *none;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNull *off = NSNull.null;
        none = @{@"bounds": off, @"position": off, @"frame": off, @"contents": off, @"backgroundColor": off, @"hidden": off, @"locations": off};
    });
    return none;
}

@implementation SGRArtworkField {
    CALayer *_solid;
    CALayer *_backdrop;
    UIColor *_color;
    UIImage *_image;
    NSString *_identity;
    NSUInteger _generation;
    BOOL _read;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.clipsToBounds = NO;
    self.accessibilityElementsHidden = YES;
    _color = SGRNeutralField();

    _solid = [CALayer layer];
    _solid.actions = noActions();
    _solid.backgroundColor = _color.CGColor;
    [self.layer addSublayer:_solid];

    _backdrop = [CALayer layer];
    _backdrop.actions = noActions();
    _backdrop.contentsGravity = kCAGravityResize;
    _backdrop.hidden = YES;
    [self.layer addSublayer:_backdrop];
    return self;
}

- (UIColor *)fieldColor {
    return _color;
}

- (CGFloat)backdropHeightNow {
    return _backdropHeight > 0 ? _backdropHeight : windowHeight(self);
}

- (void)setBleed:(UIEdgeInsets)bleed {
    _bleed = bleed;
    [self setNeedsLayout];
}

- (void)setBackdropHeight:(CGFloat)height {
    _backdropHeight = height;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    UIEdgeInsets bleed = _bleed;
    CGRect painted = CGRectMake(-bleed.left, -bleed.top, bounds.size.width + bleed.left + bleed.right, bounds.size.height + bleed.top + bleed.bottom);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _solid.frame = painted;
    _backdrop.frame = CGRectMake(0, 0, bounds.size.width, [self backdropHeightNow]);
    [CATransaction commit];
}

- (void)applyColor:(UIColor *)color animated:(BOOL)animated {
    if (!color || CGColorEqualToColor(color.CGColor, _color.CGColor)) return;
    CALayer *shown = _solid.presentationLayer ?: _solid;
    id from = (__bridge id)shown.backgroundColor;
    _color = color;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _solid.backgroundColor = color.CGColor;
    [CATransaction commit];
    if (animated && from) {
        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
        fade.fromValue = from;
        fade.toValue = (__bridge id)_solid.backgroundColor;
        fade.duration = SGRCrossfade;
        fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [_solid addAnimation:fade forKey:@"backgroundColor"];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:SGRFieldColorDidChangeNotification object:self userInfo:@{@"color": color}];
}

- (void)setProvisionalColor:(UIColor *)color {
    if (_read || !color) return;
    [self applyColor:SGRFieldColorFor(color) animated:self.window != nil];
}

- (void)setArtwork:(UIImage *)image identity:(NSString *)identity animated:(BOOL)animated {
    if (!image || image == _image || (identity && [identity isEqualToString:_identity])) return;
    _image = image;
    _identity = [identity copy];
    NSUInteger generation = ++_generation;
    SGRPaletteRequest request = {CGSizeZero, NO, NO};
    if (_showsBackdrop) request.backdropSize = CGSizeMake(self.bounds.size.width > 0 ? self.bounds.size.width : 402, [self backdropHeightNow]);
    __weak SGRArtworkField *weakSelf = self;
    [SGRPalette paletteForImage:image request:request completion:^(SGRPalette *palette) {
        SGRArtworkField *field = weakSelf;
        if (!field || !palette || generation != field->_generation) return;
        [field applyPalette:palette animated:animated && field.window != nil];
    }];
}

- (void)applyPalette:(SGRPalette *)palette animated:(BOOL)animated {
    _read = YES;
    if (_showsBackdrop && palette.backdrop) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        if (animated) {
            CATransition *fade = [CATransition animation];
            fade.type = kCATransitionFade;
            fade.duration = SGRCrossfade;
            [_backdrop addAnimation:fade forKey:@"contents"];
        }
        _backdrop.contents = (__bridge id)palette.backdrop.CGImage;
        _backdrop.hidden = NO;
        [CATransaction commit];
    }
    [self applyColor:palette.fieldColor animated:animated];
}

@end
