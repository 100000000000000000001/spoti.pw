// Keeping Spotify's views the way a redesigned screen set them: Spotify re-applies its own look on
// reuse, on state changes and on every layout pass, so each helper here either survives that or is
// cheap enough to run again on every pass. Nothing here uses `hidden` on a view Spotify arranges in a
// stack: OverflowStackView and some Encore stacks trap in updateConstraints when an arranged view
// hides, so a view goes away by alpha, touches and accessibility instead.
//
// Ownership: what a helper creates belongs to the view it was made for (associated objects), and a
// helper keeps only weak references to Spotify's views.
// Threading: main thread only, except SGRInsideClearRoot, which Appearance/Repaint.x calls from
// wherever a layer is painted.
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

// A Spotify list cell's content restyled for the field: base backgrounds (#121212, or the black AMOLED
// makes of it) cleared, white text to SGRPrimary and #B3B3B3 text to SGRSecondary (the now playing
// tint and other colours are left), Encore list row dividers at alpha 0, and image views of 40pt and
// more rounded (SGRRadiusThumb up to 64pt, SGRRadiusCover above). Idempotent; one walk of the subtree.
void SGRStyleSpotifyCell(UIView *content);

// A section header of the redesign's own over a Spotify heading cell: the title in title 2 bold, 24pt
// from the top and SGRSideMargin from the sides, and a chevron when there is somewhere to go, which
// fires `target` (Spotify's own "show all") with SGRFire. One per cell, updated on every call; the
// caller makes Spotify's heading invisible under it.
@interface SGRSectionHeader : UIView
+ (instancetype)headerInCell:(UICollectionViewCell *)cell title:(NSString *)title target:(UIControl *)target;
@end

#pragma mark - Spotify's controls and pages

// Fires a control's action the way a tap would: the actions registered for primary action triggered,
// else those for touch up inside. NO when the control has neither (an Encore control that reads its
// touches through a gesture recognizer); what was found is logged once per class.
BOOL SGRFire(UIControl *control);

// The scroll view's contentOffset through KVO, on the main thread, until `owner` or the scroll view goes
// away or the observation is invalidated. The block is handed the owner so it need not capture it
// (the owner keeps the observation, so a captured owner would never be freed).
@interface SGROffsetObservation : NSObject
- (void)invalidate;
@end
SGROffsetObservation *SGRObserveOffset(UIScrollView *scrollView, id owner, void (^changed)(id owner, CGPoint offset));

// The URI of the page `view` is in (spotify:artist:…), from the first controller up its responder
// chain that answers spt_pageURI (IdentifiedPageHostingViewController and the other page wrappers);
// kept on the view once found.
NSURL *SGRPageURI(UIView *view);

#pragma mark - repaint

// A redesigned page that paints its own field registers the view that holds Spotify's surfaces:
// Appearance/Repaint.x then clears every base surface colour (SGIsBaseSurface) set on a view inside it,
// now and whenever Spotify repaints. Registering sweeps what is already painted once. The mark lives
// on the view, so it goes with it.
void SGRRegisterClearRoot(UIView *root);
// For Repaint.x: whether any root has been registered this launch, and whether `view` is inside one
// (stopping at a visual effect view, as SGIsInside does).
BOOL SGRHasClearRoots(void);
BOOL SGRInsideClearRoot(UIView *view);
