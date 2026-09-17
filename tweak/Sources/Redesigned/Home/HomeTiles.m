// Home redesign: a shortcut tile runs its own picture across itself. The sharp cover keeps its place at the
// leading edge and fades, from 40% of its width, into the same picture blurred, which carries on to the
// trailing edge as its own edge stretched out and dims under the title until white text on it passes WCAG AA
// (Kit/SGRPalette.h, +extensionForImage:). Until the picture has loaded, the tile is Spotify's grey.
//
// The picture sits behind Spotify's stack, over the tile's own fill, so the title, the playing indicator and
// the button's touches stay Spotify's. It is made off the main thread once per picture and follows the cover
// as Spotify sets it (SGRObserveImage), since a cover lands after the tile has laid out.
//
// Tree (trees/continuous/1.txt:3454-3465, 2026-09-17): InteractableLayoutBackingButton id=Shortcut.Card.Home
// 181x48 clips > UIView 181x48 bg=#FFFFFF@0.10 (the fill), then Encore.StackView > AutoLayoutStackView >
// UIView > UIView {0, 0} 48x48 bg=#000000@0.90 r=4 (the cover's square) > Encore.ImageView > UIImageView 48x48
// and the PlaceholderView; the title's stack starts at x 56.
#import <QuartzCore/QuartzCore.h>
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Home.h"

// Where the sharp cover starts to fade, as a share of its width.
static const CGFloat kFadeFrom = 0.4;

static char kBackdropKey, kImageKey, kMaskKey, kShownKey;

// Pictures already worked out, by the image object while it lives (main thread only).
static NSMapTable<UIImage *, UIImage *> *extensions(void) {
    static NSMapTable *table;
    if (!table) table = [NSMapTable weakToStrongObjectsMapTable];
    return table;
}

@interface SGRTileParts : NSObject
@property (nonatomic, weak) UIView *fill;
@property (nonatomic, weak) UIView *square;
@property (nonatomic, weak) UIImageView *cover;
@end

@implementation SGRTileParts
@end

static SGRTileParts *partsOf(UIView *tile) {
    UIView *holder = SGRFindByIdentifier(tile, @"Encore.ImageView", &kImageKey);
    SGRTileParts *parts = [SGRTileParts new];
    for (UIView *sub in holder.subviews) {
        if ([sub isKindOfClass:UIImageView.class]) parts.cover = (UIImageView *)sub;
    }
    parts.square = holder.superview;
    UIView *first = tile.subviews.firstObject;
    if (object_getClass(first) == UIView.class && CGRectEqualToRect(first.frame, tile.bounds)) parts.fill = first;
    return parts;
}

static UIView *backdropIn(UIView *tile, UIView *fill) {
    UIView *backdrop = objc_getAssociatedObject(tile, &kBackdropKey);
    if (!backdrop) {
        backdrop = [UIView new];
        backdrop.userInteractionEnabled = NO;
        backdrop.accessibilityElementsHidden = YES;
        backdrop.layer.contentsGravity = kCAGravityResize;
        backdrop.hidden = YES;
        objc_setAssociatedObject(tile, &kBackdropKey, backdrop, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (backdrop.superview != tile) {
        if (fill) [tile insertSubview:backdrop aboveSubview:fill];
        else [tile insertSubview:backdrop atIndex:0];
    }
    if (!CGRectEqualToRect(backdrop.frame, tile.bounds)) backdrop.frame = tile.bounds;
    return backdrop;
}

static void fadeCover(UIView *square, BOOL on) {
    if (!square) return;
    if (!on) {
        if (square.layer.mask) square.layer.mask = nil;
        return;
    }
    CAGradientLayer *mask = objc_getAssociatedObject(square, &kMaskKey);
    if (!mask) {
        mask = [CAGradientLayer layer];
        mask.startPoint = CGPointMake(0, 0.5);
        mask.endPoint = CGPointMake(1, 0.5);
        mask.colors = @[(id)UIColor.blackColor.CGColor, (id)UIColor.clearColor.CGColor];
        mask.locations = @[@(kFadeFrom), @1];
        mask.actions = @{@"bounds": NSNull.null, @"position": NSNull.null};
        objc_setAssociatedObject(square, &kMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!CGRectEqualToRect(mask.frame, square.bounds)) mask.frame = square.bounds;
    if (square.layer.mask != mask) square.layer.mask = mask;
}

static void show(UIView *tile, UIView *backdrop, UIView *square, UIImage *extension, BOOL animated) {
    if (!extension) {
        backdrop.hidden = YES;
        backdrop.layer.contents = nil;
        fadeCover(square, NO);
        return;
    }
    if (backdrop.layer.contents == (__bridge id)extension.CGImage && !backdrop.hidden) {
        fadeCover(square, YES);
        return;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (animated && tile.window && !backdrop.hidden) {
        CATransition *fade = [CATransition animation];
        fade.type = kCATransitionFade;
        fade.duration = SGRCrossfade;
        [backdrop.layer addAnimation:fade forKey:@"contents"];
    }
    backdrop.layer.contents = (__bridge id)extension.CGImage;
    backdrop.hidden = NO;
    [CATransaction commit];
    fadeCover(square, YES);
}

static void refresh(UIView *tile) {
    SGRTileParts *parts = partsOf(tile);
    UIImageView *cover = parts.cover;
    UIView *square = parts.square;
    if (!cover || !square || square.bounds.size.width < 20 || tile.bounds.size.width <= square.bounds.size.width) return;
    UIView *backdrop = backdropIn(tile, parts.fill);

    UIImage *image = cover.image;
    // The cover's placeholder shows while there is no picture, over Spotify's grey.
    if (!image) {
        objc_setAssociatedObject(tile, &kShownKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        show(tile, backdrop, square, nil, NO);
        return;
    }
    UIImage *known = [extensions() objectForKey:image];
    if (known && CGSizeEqualToSize(known.size, CGSizeMake(ceil(tile.bounds.size.width), ceil(tile.bounds.size.height)))) {
        objc_setAssociatedObject(tile, &kShownKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        show(tile, backdrop, square, known, YES);
        return;
    }
    if (objc_getAssociatedObject(tile, &kShownKey) == image) return;
    objc_setAssociatedObject(tile, &kShownKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGFloat art = CGRectGetMaxX([square convertRect:square.bounds toView:tile]);
    __weak UIView *weakTile = tile;
    [SGRPalette extensionForImage:image size:tile.bounds.size artWidth:art completion:^(UIImage *extension) {
        UIView *strongTile = weakTile;
        if (extension) [extensions() setObject:extension forKey:image];
        // A tile reused for another cover in the meantime has asked for that one.
        if (!strongTile || objc_getAssociatedObject(strongTile, &kShownKey) != image) return;
        SGRTileParts *now = partsOf(strongTile);
        show(strongTile, backdropIn(strongTile, now.fill), now.square, extension, YES);
    }];
}

void SGRHomeStyleTile(UIView *tile) {
    CFTimeInterval began = SGRHomeProbeBegin();
    UIImageView *cover = partsOf(tile).cover;
    if (!cover) return;
    __weak UIView *weakTile = tile;
    // The block is replaced on every pass, so a cover taken into another tile tells the tile it is in now.
    SGRObserveImage(cover, ^(UIImageView *view) {
        UIView *strongTile = weakTile;
        if (strongTile && [view isDescendantOfView:strongTile]) refresh(strongTile);
    });
    refresh(tile);
    SGRHomeProbeEnd(SGRHomeProbeTiles, began);
}
