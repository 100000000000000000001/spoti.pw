// The hero header of a redesigned page (the artist page first): the picture across the full width
// under the status bar, its lower part going soft through a blurred copy and dissolving into the
// field colour, the title and a meta line over the dissolved part, and a slot for the action row
// (SGRGlass.h) under them. Laid out for whatever height it is given, measured from its bottom edge:
//
//     title       bottom at H - 98, large title bold, up to 2 lines, centred, scales down to 0.7
//     meta        H - 94, 18 tall, footnote in SGRSecondary, hidden while empty
//     actionSlot  H - 64, 48 tall, full width
//     dissolve    field colour from transparent at 0.45 H to opaque at H
//
// Scrolling moves only transforms and alphas (applyScrollOffset:), never frames or layout: the picture
// stretches from its bottom edge on overscroll, drifts at 0.3 of the scroll speed after that, and the
// texts and actions fade before they reach the top bar. Under Reduce Motion only the fade is left.
//
// Ownership: the screen owns the hero and puts it in its page. The hero keeps a weak reference to the
// field it is bound to and the images it was given.
// Threading: main thread only; the blurred copy is made off it.
#import <UIKit/UIKit.h>

@class SGRArtworkField;

@interface SGRHeroHeader : UIView
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *meta;
// Where the action row goes; the hero lays out nothing inside it.
@property (nonatomic, readonly) UIView *actionSlot;

// The picture fades in over 0.25s and its blurred copy follows when it is ready; the same image
// again is a no-op, nil leaves the picture as it is.
- (void)setImage:(UIImage *)image animated:(BOOL)animated;
// The dissolve takes the field's colour now and crossfades with it from then on.
- (void)bindToField:(SGRArtworkField *)field;
// `offset` is the page's vertical scroll offset with 0 at rest (negative on overscroll), `distance`
// how far the page scrolls before the header is pinned under the top bar.
- (void)applyScrollOffset:(CGFloat)offset collapseDistance:(CGFloat)distance;
@end
