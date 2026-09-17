// Player redesign: the footer as the Music app's row of three glyphs, lyrics, devices and queue, spread
// evenly across the player, and no share button.
//
// Spotify's footer is Connect with the device's name at the leading edge, share, and the queue at the
// trailing edge. Connect and the queue stay Spotify's controls (the device sheet, the remote device
// tint, the Jam avatars) and are only moved, by a translation of the arranged view that holds each: a
// transform survives the stack view laying them out again, and moving the holder keeps its touches
// inside its own bounds. The device name goes transparent, since the glyph alone sits in the middle.
// Spotify has no lyrics control down here, so that one is the Kit's glyph button, which fires the
// lyrics card's own expand button, or opens spotify:lyrics:fullscreen when there is no card.
//
// Tree (trees/clean/player/01.txt:295-320): FooterElementsUnit's view 402x44 > UIStackView 382x44 >
// ElementView > ConnectButtonOutputSwitcherViewHolder id=Components.ConnectButtonOutputSwitcher 153x36
// (a 19x19 UIImageView glyph and a MarqueeLabel with the device name), a spacer, a hidden media trimmer,
// ElementView > EncoreButton id=ShareButtonNowPlayingView 44x44, ElementView > Queue control
// id=QueueButtonNowPlaying 47x32. The card's button is id=lyrics-expand-button, an EncoreButton, which
// is a UIButton (trees/clean/lyrics/01.txt:1013, objc-meta-Spotify.txt:216095).
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Player.h"

static const CGFloat kLyricsGlyphSize = 20;
// Where the three glyphs sit, as parts of the footer's width.
static const CGFloat kLeading = 0.2, kMiddle = 0.5, kTrailing = 0.8;
static const CGFloat kGlyphMaxWidth = 30;

static char kConnectKey, kShareKey, kTrimmerKey, kQueueKey, kLyricsGlyphKey, kExpandKey;
static __weak SGRGlyphButton *sg_lyricsGlyph;

// The view the footer's stack view arranges around `view`.
static UIView *arrangedAround(UIView *view, UIView *host) {
    for (UIView *v = view; v && v != host; v = v.superview) {
        if ([v.superview isKindOfClass:UIStackView.class]) return v;
    }
    return nil;
}

// Where `point` of `view` is in the host with the arranged view's own transform left out.
static CGFloat untransformedX(UIView *arranged, UIView *view, CGPoint point, UIView *host) {
    CGPoint local = [view convertPoint:point toView:arranged];
    CGPoint inRow = CGPointMake(arranged.center.x + local.x - CGRectGetMidX(arranged.bounds), arranged.center.y);
    return [arranged.superview convertPoint:inRow toView:host].x;
}

static CGFloat moveTo(UIView *arranged, UIView *view, CGPoint point, UIView *host, CGFloat x) {
    if (!arranged) return -1;
    CGFloat from = untransformedX(arranged, view, point, host);
    CGAffineTransform transform = CGAffineTransformMakeTranslation(round(x - from), 0);
    if (!CGAffineTransformEqualToTransform(arranged.transform, transform)) arranged.transform = transform;
    return from;
}

#pragma mark - lyrics

static void openLyrics(void) {
    UIView *card = SGRPlayerLyricsCard();
    UIControl *expand = (UIControl *)SGRFindByIdentifier(card, @"lyrics-expand-button", &kExpandKey);
    NSString *how = @"nothing";
    if ([expand isKindOfClass:UIControl.class] && SGRFire(expand)) how = @"the card's expand button";
    else if (SGROpenURI([NSURL URLWithString:@"spotify:lyrics:fullscreen"])) how = @"spotify:lyrics:fullscreen";
    SGLog(@"redesign player: lyrics glyph opened the page by %@", how);
}

void SGRPlayerLyricsCardChanged(void) {
    SGRGlyphButton *glyph = sg_lyricsGlyph;
    BOOL enabled = SGRPlayerLyricsCard() != nil;
    if (!glyph || glyph.enabled == enabled) return;
    // The card turns up once the player has fetched it, well after the footer laid out: a fade, not a
    // pop. While the player opens or closes the two come and go together, so nothing is animated then.
    if (!glyph.window || SGRPlayerIsTransitioning()) glyph.enabled = enabled;
    else SGRAnimate(SGRMotionFade, ^{ glyph.enabled = enabled; }, nil);
}

static SGRGlyphButton *lyricsGlyphIn(UIView *host) {
    SGRGlyphButton *glyph = objc_getAssociatedObject(host, &kLyricsGlyphKey);
    if (!glyph) {
        glyph = [SGRGlyphButton buttonWithSymbol:@"quote.bubble" pointSize:kLyricsGlyphSize title:@"Lyrics"];
        glyph.glyph.tintColor = SGRSecondary();
        glyph.onTap = ^{ openLyrics(); };
        objc_setAssociatedObject(host, &kLyricsGlyphKey, glyph, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (glyph.superview != host) [host addSubview:glyph];
    sg_lyricsGlyph = glyph;
    return glyph;
}

#pragma mark - the row

static UIView *connectGlyphIn(UIView *holder) {
    __block UIView *glyph = nil;
    SGForEachView(holder, ^(UIView *view) {
        if (!glyph && [view isKindOfClass:UIImageView.class] && view.bounds.size.width > 0 && view.bounds.size.width <= kGlyphMaxWidth) glyph = view;
    });
    return glyph;
}

%hook _TtC20NowPlaying_ModesImpl18FooterElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *host = ((UIViewController *)self).viewIfLoaded;
    if (!host) return;
    // The unit lays out before its row does, and the moves are measured from where the row put things.
    [SGRowIn(host) layoutIfNeeded];
    CGFloat width = host.bounds.size.width, middleY = CGRectGetMidY(host.bounds);
    BOOL rtl = host.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;

    UIView *share = SGRFindByIdentifier(host, @"ShareButtonNowPlayingView", &kShareKey);
    // The arranged view goes too: a view that takes touches swallows them even with nothing on it.
    SGRPlayerVanish(share);
    SGRPlayerVanish(arrangedAround(share, host));
    // Spotify's clip button, hidden in every clean tree, would turn up where the queue moves to.
    UIView *trimmer = SGRFindByIdentifier(host, @"nowplaying-npv-media-trimmer-navigation-button", &kTrimmerKey);
    SGRPlayerVanish(trimmer);
    SGRPlayerVanish(arrangedAround(trimmer, host));

    SGRGlyphButton *lyrics = lyricsGlyphIn(host);
    lyrics.bounds = CGRectMake(0, 0, 44, 44);
    lyrics.center = CGPointMake(round(width * (rtl ? kTrailing : kLeading)), middleY);
    SGRPlayerLyricsCardChanged();

    UIView *connect = SGRFindByIdentifier(host, @"Components.ConnectButtonOutputSwitcher", &kConnectKey);
    UIView *glyph = connectGlyphIn(connect);
    for (UIView *view = glyph.superview; view && view != connect; view = view.superview) {
        for (UIView *sibling in view.subviews) {
            if ([NSStringFromClass(sibling.class) containsString:@"MarqueeLabel"]) SGRPlayerVanish(sibling);
        }
    }
    UIView *pinned = glyph ?: connect;
    CGFloat connectFrom = moveTo(arrangedAround(connect, host), pinned, CGPointMake(CGRectGetMidX(pinned.bounds), CGRectGetMidY(pinned.bounds)), host, round(width * kMiddle));

    UIView *queue = SGRFindByIdentifier(host, @"QueueButtonNowPlaying", &kQueueKey);
    CGFloat queueFrom = moveTo(arrangedAround(queue, host), queue, CGPointMake(CGRectGetMidX(queue.bounds), CGRectGetMidY(queue.bounds)), host, round(width * (rtl ? kLeading : kTrailing)));

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"redesign player: footer lyrics at %.0f, connect %.0f (%@) to %.0f, queue %.0f to %.0f, share %@", lyrics.center.x,
              connectFrom, glyph ? @"glyph" : @"button", round(width * kMiddle), queueFrom, round(width * (rtl ? kLeading : kTrailing)), share ? @"gone" : @"not found");
    });
}
%end

%ctor {
    if (!SGRedesignOn(@"player")) return;
    %init;
    SGRequireClasses(@[@"_TtC20NowPlaying_ModesImpl18FooterElementsUnit"]);
}
