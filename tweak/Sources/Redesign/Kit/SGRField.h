// The artwork field: one continuous colour taken from the artwork's bottom edge (SGRPalette.h) behind
// a whole redesigned page, with no card and no seam anywhere. The player's field also carries the
// artwork itself at the top, blurred and dimmed and dissolving into the colour (showsBackdrop).
//
// Nothing is blurred live and nothing is masked: the view draws a solid colour layer, a black
// gradient layer under AMOLED and at most one bitmap layer rendered off the main thread, so it costs
// one composited layer or two while the page moves. A new colour or bitmap crossfades over
// SGRCrossfade; the same image again is a no-op.
//
// Ownership: the screen that installs a field owns it (usually retained by its superview and an
// associated object). The field retains its last image and palette only.
// Threading: main thread only; the palette work it starts runs off it.
#import <UIKit/UIKit.h>

// Posted on the main thread by a field whose colour changed, with the field as the object and the
// new colour under "color".
extern NSNotificationName const SGRFieldColorDidChangeNotification;

@interface SGRArtworkField : UIView
// Where the colour, the AMOLED fade and the backdrop reach past the bounds (overscroll, a plane
// that does not clip): positive values draw outside. The field never clips.
@property (nonatomic) UIEdgeInsets bleed;
@property (nonatomic) BOOL showsBackdrop;
// The backdrop's height in points from the top of the bounds; 0 is the window's height.
@property (nonatomic) CGFloat backdropHeight;
// With AMOLED on: where the colour starts fading to black and where it is black, in points from the
// top of the bounds; 0 is 55% and 100% of the window's height.
@property (nonatomic) CGFloat amoledFadeFrom, amoledFadeTo;
// SGRNeutralField until a colour arrives.
@property (nonatomic, readonly) UIColor *fieldColor;

// A colour Spotify already has for the page (the player's background colour), made fit to be a field
// and shown until the first artwork has been read; ignored after that.
- (void)setProvisionalColor:(UIColor *)color;
// Reads the artwork off the main thread and crossfades the result in (without animation when
// `animated` is NO or the field is not in a window). The same image, or the same non-nil identity,
// as the last call is a no-op, and a result that lands after a newer call is dropped. nil keeps
// what the field shows.
- (void)setArtwork:(UIImage *)image identity:(NSString *)identity animated:(BOOL)animated;
@end
