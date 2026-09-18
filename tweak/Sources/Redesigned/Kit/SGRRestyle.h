// Keeping Spotify's views the way a redesigned screen set them: Spotify re-applies its own look on
// reuse, on state changes and on every layout pass, so each helper here either survives that or is
// cheap enough to run again on every pass. Nothing here uses `hidden` on a view Spotify arranges in a
// stack: OverflowStackView and some Encore stacks trap in updateConstraints when an arranged view
// hides, so a view goes away by alpha, touches and accessibility instead.
//
// Ownership: what a helper creates belongs to the view it was made for (associated objects), and a
// helper keeps only weak references to Spotify's views.
// Threading: main thread only.
#import <UIKit/UIKit.h>

#pragma mark - views

// Alpha 0, no touches, hidden from accessibility, and kept so: the instance becomes a runtime subclass
// of its own class (the way KVO does it, `class` still answers the original) whose setAlpha: and
// setUserInteractionEnabled: hold those values. For plain UIKit views (a UIImageView, a UILabel); a
// Swift class, or an instance already observed with KVO, gets the values once instead, re-applied on
// the next call, and a log line says so once.
void SGRSuppress(UIView *view);

// Digits of one width in the label, kept through Spotify's own setText:, setAttributedText: and
// setFont: by a runtime subclass of the instance, like SGRSuppress. Idempotent.
void SGRMonospacedDigits(UILabel *label);

// `changed` after every setImage: on the image view, Spotify's included, for as long as the view lives, by a
// runtime subclass of the instance like SGRSuppress. A second call replaces the block. NO when the view
// cannot be subclassed (a KVO-observed instance): the caller then only sees what its own passes read.
BOOL SGRObserveImage(UIImageView *view, void (^changed)(UIImageView *view));

// `laidOut` after every layoutSubviews of the view, Spotify's included, for as long as the view lives, by
// a runtime subclass of the instance like SGRSuppress. A second call replaces the block, and a pass started
// from inside the block is not reported again. NO when the view cannot be subclassed (one of Spotify's Swift
// classes, a KVO-observed instance): the caller then has only the passes it hooks itself to work from.
//
// For a screen that arranges Spotify's controls its own way: a parent lays its children out after the
// hook that placed them has returned, so frames set from an ancestor's pass are the ones overwritten.
BOOL SGRObserveLayout(UIView *view, void (^laidOut)(UIView *view));

// The first view under `root` (itself included) with the accessibility identifier, depth first. The
// answer is kept weakly on `root` under `cacheKey` and searched for again only when it is gone, has
// left `root` or changed its identifier. nil when there is none; a miss is not cached.
UIView *SGRFindByIdentifier(UIView *root, NSString *identifier, const void *cacheKey);

// A view that draws only a shadow, for a view whose own layer clips (rounded artwork): made once per
// host under `key`, inserted at the bottom of `host`. The caller gives it its frame and transform; its
// shadowPath follows its bounds and cornerRadius.
@interface SGRShadowPlate : UIView
@property (nonatomic) CGFloat cornerRadius;   // SGRRadiusArtwork unless set
@end
SGRShadowPlate *SGRShadowPlateIn(UIView *host, const void *key);

#pragma mark - Spotify's controls and pages

// Fires a control's action the way a tap would: the actions registered for primary action triggered,
// else those for touch up inside. NO when the control has neither (an Encore control that reads its
// touches through a gesture recognizer); what was found is logged once per class.
BOOL SGRFire(UIControl *control);
