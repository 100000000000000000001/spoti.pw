#import "Core/SGCore.h"
#import "SGRHero.h"
#import "SGRField.h"
#import "SGRPalette.h"
#import "SGRTokens.h"

static const CGFloat kTitleBottom = 98, kMetaTop = 94, kMetaHeight = 18, kActionTop = 64;
static const CGFloat kScrimHeight = 140, kScrimAlpha = 0.3;
static const CGFloat kDissolveFrom = 0.45, kDissolveMid = 0.72, kDissolveMidAlpha = 0.55;
static const CGFloat kParallax = 0.3;
static const CGFloat kFadeStart = 300, kFadeLength = 120;   // above the hero's bottom edge, in points of scroll
// The picture's clip reaches this far above the hero so an overscroll stretch can grow upwards; it
// clips the sides and the bottom only.
static const CGFloat kStretchRoom = 1000;
static const NSTimeInterval kImageFade = 0.25;

@interface SGRGradientView : UIView
@end

@implementation SGRGradientView
+ (Class)layerClass {
    return CAGradientLayer.class;
}
@end

@implementation SGRHeroHeader {
    UIView *_clip;
    UIImageView *_photo;
    UIImageView *_blurred;
    SGRGradientView *_dissolve;
    UILabel *_titleLabel;
    UILabel *_metaLabel;
    UIView *_actionSlot;
    __weak SGRArtworkField *_field;
    UIImage *_image;
    NSUInteger _generation;
    CGFloat _lastPictureOffset, _lastFade;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _lastPictureOffset = NAN;
    _lastFade = NAN;

    _clip = [UIView new];
    _clip.clipsToBounds = YES;
    _clip.userInteractionEnabled = NO;
    _clip.accessibilityElementsHidden = YES;
    [self addSubview:_clip];

    _photo = [UIImageView new];
    _photo.contentMode = UIViewContentModeScaleAspectFill;
    CAGradientLayer *scrim = [CAGradientLayer layer];
    scrim.colors = @[(id)[UIColor colorWithWhite:0 alpha:kScrimAlpha].CGColor, (id)[UIColor colorWithWhite:0 alpha:0].CGColor];
    [_photo.layer addSublayer:scrim];
    [_clip addSubview:_photo];

    _blurred = [UIImageView new];
    _blurred.contentMode = UIViewContentModeScaleAspectFill;
    _blurred.alpha = 0;
    [_clip addSubview:_blurred];

    _dissolve = [SGRGradientView new];
    [self paintDissolve:SGRNeutralField() animated:NO];
    [_clip addSubview:_dissolve];

    _titleLabel = [UILabel new];
    _titleLabel.textColor = SGRPrimary();
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.numberOfLines = 2;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.7;
    _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self addSubview:_titleLabel];

    _metaLabel = [UILabel new];
    _metaLabel.textColor = SGRSecondary();
    _metaLabel.textAlignment = NSTextAlignmentCenter;
    _metaLabel.isAccessibilityElement = NO;
    [self addSubview:_metaLabel];

    _actionSlot = [UIView new];
    [self addSubview:_actionSlot];

    [self applyFonts];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(contentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (UIView *)actionSlot {
    return _actionSlot;
}

- (void)applyFonts {
    // The header keeps Spotify's height, so at the largest sizes the title shrinks rather than grows.
    _titleLabel.font = SGRFont(UIFontTextStyleLargeTitle, UIFontWeightBold, UIContentSizeCategoryAccessibilityMedium);
    _metaLabel.font = SGRFont(UIFontTextStyleFootnote, UIFontWeightRegular, UIContentSizeCategoryExtraExtraExtraLarge);
}

- (void)contentSizeChanged:(NSNotification *)note {
    [self applyFonts];
    [self setNeedsLayout];
}

#pragma mark - content

- (NSString *)title {
    return _titleLabel.text;
}

- (void)setTitle:(NSString *)title {
    if ([title isEqualToString:_titleLabel.text] || (!title && !_titleLabel.text)) return;
    _titleLabel.text = title;
    [self updateAccessibility];
    [self setNeedsLayout];
}

- (NSString *)meta {
    return _metaLabel.text;
}

- (void)setMeta:(NSString *)meta {
    if ([meta isEqualToString:_metaLabel.text] || (!meta && !_metaLabel.text)) return;
    _metaLabel.text = meta;
    _metaLabel.hidden = meta.length == 0;
    [self updateAccessibility];
}

// The meta line is read with the title, as one element.
- (void)updateAccessibility {
    NSString *title = _titleLabel.text ?: @"";
    _titleLabel.accessibilityLabel = _metaLabel.text.length ? [NSString stringWithFormat:@"%@, %@", title, _metaLabel.text] : title;
}

- (void)setImage:(UIImage *)image animated:(BOOL)animated {
    if (!image || image == _image) return;
    _image = image;
    animated = animated && self.window;
    UIImageView *photo = _photo;
    if (animated) {
        [UIView transitionWithView:photo duration:kImageFade options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction animations:^{
            photo.image = image;
        } completion:nil];
    } else {
        photo.image = image;
    }

    NSUInteger generation = ++_generation;
    SGRPaletteRequest request = {CGSizeZero, YES, NO};
    __weak SGRHeroHeader *weakSelf = self;
    [SGRPalette paletteForImage:image request:request completion:^(SGRPalette *palette) {
        SGRHeroHeader *hero = weakSelf;
        if (!hero || !palette.dissolve || generation != hero->_generation) return;
        [hero showBlurred:palette.dissolve];
    }];
}

- (void)showBlurred:(UIImage *)image {
    UIImageView *blurred = _blurred;
    if (!self.window) {
        blurred.image = image;
        blurred.alpha = 1;
        return;
    }
    if (blurred.alpha > 0) {
        [UIView transitionWithView:blurred duration:SGRCrossfade options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction animations:^{
            blurred.image = image;
        } completion:nil];
        return;
    }
    blurred.image = image;
    SGRAnimate(SGRMotionFade, ^{ blurred.alpha = 1; }, nil);
}

- (void)bindToField:(SGRArtworkField *)field {
    if (_field) [NSNotificationCenter.defaultCenter removeObserver:self name:SGRFieldColorDidChangeNotification object:_field];
    _field = field;
    if (!field) return;
    [self paintDissolve:field.fieldColor animated:NO];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(fieldColorChanged:) name:SGRFieldColorDidChangeNotification object:field];
}

- (void)fieldColorChanged:(NSNotification *)note {
    UIColor *color = note.userInfo[@"color"];
    if (color) [self paintDissolve:color animated:self.window != nil];
}

// Started in the same transaction as the field's own colour animation, so the two stay one colour.
- (void)paintDissolve:(UIColor *)color animated:(BOOL)animated {
    CAGradientLayer *layer = (CAGradientLayer *)_dissolve.layer;
    NSArray *from = ((CAGradientLayer *)layer.presentationLayer ?: layer).colors;
    NSArray *to = @[(id)[color colorWithAlphaComponent:0].CGColor, (id)[color colorWithAlphaComponent:kDissolveMidAlpha].CGColor, (id)color.CGColor];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    layer.colors = to;
    layer.locations = @[@0, @((kDissolveMid - kDissolveFrom) / (1 - kDissolveFrom)), @1];
    [CATransaction commit];
    if (!animated || !from) return;
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"colors"];
    fade.fromValue = from;
    fade.toValue = layer.colors;
    fade.duration = SGRCrossfade;
    fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:fade forKey:@"colors"];
}

#pragma mark - layout and scroll

// Only the action row takes touches; anywhere else the touch belongs to the page under the hero.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width, height = self.bounds.size.height;
    CGRect picture = CGRectMake(0, kStretchRoom, width, height);
    [UIView performWithoutAnimation:^{
        CGAffineTransform photoTransform = _photo.transform, blurredTransform = _blurred.transform;
        _photo.transform = CGAffineTransformIdentity;
        _blurred.transform = CGAffineTransformIdentity;
        _clip.frame = CGRectMake(0, -kStretchRoom, width, height + kStretchRoom);
        _photo.frame = picture;
        _blurred.frame = picture;
        _photo.transform = photoTransform;
        _blurred.transform = blurredTransform;
        _dissolve.frame = CGRectMake(0, kStretchRoom + height * kDissolveFrom, width, height * (1 - kDissolveFrom));
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _photo.layer.sublayers.firstObject.frame = CGRectMake(0, 0, width, kScrimHeight);
        [CATransaction commit];

        CGFloat textWidth = MAX(0, width - 2 * SGRSideMargin);
        CGFloat twoLines = ceil(_titleLabel.font.lineHeight * 2);
        CGFloat titleHeight = MIN(twoLines, ceil([_titleLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)].height));
        _titleLabel.frame = CGRectMake(SGRSideMargin, height - kTitleBottom - titleHeight, textWidth, titleHeight);
        _metaLabel.frame = CGRectMake(SGRSideMargin, height - kMetaTop, textWidth, MAX(kMetaHeight, ceil(_metaLabel.font.lineHeight)));
        _actionSlot.frame = CGRectMake(0, height - kActionTop, width, SGRActionHeight);
    }];
}

- (void)applyScrollOffset:(CGFloat)offset collapseDistance:(CGFloat)distance {
    CGFloat height = self.bounds.size.height;
    if (height <= 0) return;
    CGFloat pictureOffset = SGRReduceMotion() ? 0 : MIN(offset, MAX(0, distance));
    if (pictureOffset != _lastPictureOffset) {
        _lastPictureOffset = pictureOffset;
        CGAffineTransform transform = CGAffineTransformIdentity;
        if (pictureOffset < 0) {
            // Scaled about the centre, then moved so the bottom edge stays where it is.
            CGFloat scale = (height - pictureOffset) / height;
            transform = CGAffineTransformMake(scale, 0, 0, scale, 0, height / 2 * (1 - scale));
        } else if (pictureOffset > 0) {
            transform = CGAffineTransformMakeTranslation(0, kParallax * pictureOffset);
        }
        _photo.transform = transform;
        _blurred.transform = transform;
    }
    CGFloat fade = MIN(1, MAX(0, (offset - (height - kFadeStart)) / kFadeLength));
    if (fade != _lastFade) {
        _lastFade = fade;
        CGFloat alpha = 1 - fade;
        _titleLabel.alpha = alpha;
        _metaLabel.alpha = alpha;
        _actionSlot.alpha = alpha;
        _actionSlot.userInteractionEnabled = alpha > 0.1;
    }
}

@end
