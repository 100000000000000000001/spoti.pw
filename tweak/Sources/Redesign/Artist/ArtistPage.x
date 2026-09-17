// Artist page redesign, the page (RedesignArtist.h): finds a redesigned artist page, lays the Kit's field
// behind it, puts the Kit's hero over Spotify's header and takes the tab strip away.
//
// Trees (trees/clean/artist/01.txt): LoadableTemplateViewController's view holds TemplateView
// (id=creator-page), and TemplateView the tab layout: an overlay scroll view that takes the pan
// (id=PCFFTabLayoutViewController.overlayScrollView) and over it the container scroll view
// (id=PCFFTabLayoutViewController.containerScrollView), whose stack holds the HeaderContainer (504 tall,
// 568 with a pre-save row under the buttons) and the tabs: the strip (id=Components.UI.TabsSectionHeading,
// 44 tall) over a paging scroll view of one list per tab. Scrolling down, the container stops at the
// header's height less 100 (02.txt: 468 of 568, 09.txt: 404 of 504) and Spotify keeps a 100pt band of
// its header pinned under the navigation bar while the list scrolls on.
//
// The page's URI comes from its hosting controller, MusicAppPageHostingViewController, a subclass of
// IdentifiedPageHostingViewController (objc-meta-Spotify.txt:1406777), whose spt_pageURI
// (objc-methods.txt:74510) SGRPageURI reads; an author's page is the same template with another URI.
//
// Spotify's header is ImageHeaderView: the photo (id=Components.Header.UI.ArtworkImage.ImageView holding an
// EncoreImageView, a UIImageView), the name (id=Encore.AdaptiveTitle around a CoreLabel), the listeners
// (id=Components.Header.UI.Metadata-internal), the explore deck of videos, and the buttons: Follow
// (id=Curation.FollowButtonElementKit.FollowButton, an Encore button), Shuffle (id=Components.UI.ShuffleButton,
// a UIButton whose 4pt green dot shows while shuffle is on) and Play (id=header-play-button, a PlayButtonView
// whose uiButtonTapped is its own action, objc-methods.txt:68122). It turns invisible and the hero lies over
// it in the HeaderContainer, so the hero scrolls with the page and Spotify's controls keep working under
// the glass buttons that fire them.
#import <objc/runtime.h>
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Redesign/Kit/SGRKit.h"
#import "RedesignArtist.h"

// The band of Spotify's header left pinned under the navigation bar (02.txt, 09.txt).
static const CGFloat kPinnedHeader = 100;

static Class sg_templateClass, sg_imageHeaderClass;
static char kPageKey, kArtworkContext;

@protocol SGArtistPlayButton
- (void)uiButtonTapped;
@end

static NSString *labelTextIn(UIView *root) {
    __block NSString *text = nil;
    if (!root) return nil;
    SGForEachView(root, ^(UIView *view) {
        if (!text && [view isKindOfClass:UILabel.class] && ((UILabel *)view).text.length) text = ((UILabel *)view).text;
    });
    return text;
}

static UIButton *buttonIn(UIView *root) {
    __block UIButton *button = nil;
    if (!root) return nil;
    SGForEachView(root, ^(UIView *view) {
        if (!button && [view isKindOfClass:UIButton.class]) button = (UIButton *)view;
    });
    return button;
}

// The shuffle button's dot (01.txt: a 4x4 UIView, hidden while shuffle is off).
static BOOL shuffleDotShown(UIView *shuffle) {
    for (UIView *view in shuffle.subviews) {
        CGFloat width = CGRectGetWidth(view.bounds);
        if (width > 0 && width <= 6 && ![view isKindOfClass:UIImageView.class]) return !view.hidden && view.alpha > 0.01;
    }
    return NO;
}

// A tap on one of Spotify's controls: its registered action, else its own VoiceOver activation, which an
// Encore control that reads touches through a gesture recognizer still answers.
static BOOL fire(UIControl *control) {
    if (!control) return NO;
    return SGRFire(control) || [control accessibilityActivate];
}

@interface SGArtistPage () <SGRPlayerStateObserver>
- (instancetype)initWithURI:(NSString *)uri template:(UIView *)template;
- (void)templateDidLayout:(UIView *)template;
- (void)headerContainerDidLayout:(UIView *)container;
- (void)stockHeaderDidLayout:(UIView *)header;
- (BOOL)hideTabsIn:(UIView *)root;
@end

@implementation SGArtistPage {
    SGRArtworkField *_field;
    SGRHeroHeader *_hero;
    SGRGlassButton *_shuffle, *_play, *_follow;
    __weak UIScrollView *_container, *_overlay;
    __weak UIImageView *_artworkView;
    __weak UIView *_stockHeader, *_playControl;
    __weak UIControl *_shuffleControl, *_followControl;
    UIImage *_image;
    CGFloat _containerY, _overlayY;
    CFTimeInterval _lastMirror;
    NSUInteger _missedReads;
    BOOL _observing, _tabsHidden, _mirrorScheduled;
}

- (instancetype)initWithURI:(NSString *)uri template:(UIView *)template {
    if (!(self = [super init])) return nil;
    _uri = [uri copy];
    _field = [[SGRArtworkField alloc] initWithFrame:template.bounds];
    _field.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _field.userInteractionEnabled = NO;
    [template insertSubview:_field atIndex:0];
    // Spotify paints the page, its lists and its rows in its base grey (#121212); inside the template it
    // is cleared now and whenever it is painted again, so the field shows through.
    SGRRegisterClearRoot(template);
    SGRAddPlayerStateObserver(self);
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"artist: page %@, field and clear root in %@", uri, NSStringFromClass(template.class)); });
    return self;
}

- (void)dealloc {
    [self watchArtwork:nil];
}

#pragma mark - page

- (void)templateDidLayout:(UIView *)template {
    if (template.subviews.firstObject != _field) [template insertSubview:_field atIndex:0];
    if (!CGRectEqualToRect(_field.frame, template.bounds)) _field.frame = template.bounds;
    if (!_observing) [self observeScrollIn:template];
    if (!_tabsHidden) [self hideTabsIn:template];
}

- (void)observeScrollIn:(UIView *)template {
    static char containerKey, overlayKey;
    UIScrollView *container = (UIScrollView *)SGRFindByIdentifier(template, @"PCFFTabLayoutViewController.containerScrollView", &containerKey);
    if (![container isKindOfClass:UIScrollView.class]) return;
    UIScrollView *overlay = (UIScrollView *)SGRFindByIdentifier(template, @"PCFFTabLayoutViewController.overlayScrollView", &overlayKey);
    _observing = YES;
    _container = container;
    SGRObserveOffset(container, self, ^(id owner, CGPoint offset) { [(SGArtistPage *)owner containerMoved:offset]; });
    // The overlay takes the pan, so an overscroll may show there only; the container is where the header is.
    if ([overlay isKindOfClass:UIScrollView.class]) {
        _overlay = overlay;
        SGRObserveOffset(overlay, self, ^(id owner, CGPoint offset) { [(SGArtistPage *)owner overlayMoved:offset]; });
    }
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"artist: scroll observed, container inset %.0f, overlay %@", container.adjustedContentInset.top, overlay ? @"found" : @"missing");
    });
}

- (void)containerMoved:(CGPoint)offset {
    _containerY = offset.y + _container.adjustedContentInset.top;
    [self applyScroll];
}

- (void)overlayMoved:(CGPoint)offset {
    _overlayY = offset.y + _overlay.adjustedContentInset.top;
    if (_overlayY < 0 || _containerY <= 0) [self applyScroll];
}

// The hero's own scroll response: stretch on overscroll (from whichever scroll view shows it), drift, and
// the texts and buttons fading before the navigation bar. Only transforms and alphas change here.
- (void)applyScroll {
    if (!_hero) return;
    CGFloat y = _containerY;
    if (y <= 0 && _overlayY < y) y = _overlayY;
    CGFloat distance = MAX(0, CGRectGetHeight(_hero.bounds) - kPinnedHeader);
    [_hero applyScrollOffset:y collapseDistance:distance];
    if (y < -1) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{ SGLog(@"artist: overscroll, container %.0f overlay %.0f", self->_containerY, self->_overlayY); });
    } else if (distance > 0 && y >= distance) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{ SGLog(@"artist: header pinned at %.0f, container %.0f overlay %.0f", distance, self->_containerY, self->_overlayY); });
    }
}

// Trees (01.txt): the strip lives in a LegacyUI AutoLayoutStackView, so it goes invisible rather than
// hidden; the paging scroll view beside it moves up into its place and stops swiping, which leaves the
// Music list, the way Features/Artist/Artist.x hides it.
- (BOOL)hideTabsIn:(UIView *)root {
    static char stripKey;
    UIView *strip = SGRFindByIdentifier(root, @"Components.UI.TabsSectionHeading", &stripKey);
    if (!strip.superview) return NO;
    _tabsHidden = YES;
    if (strip.alpha != 0) strip.alpha = 0;
    if (strip.userInteractionEnabled) strip.userInteractionEnabled = NO;
    if (!strip.accessibilityElementsHidden) strip.accessibilityElementsHidden = YES;
    CGFloat lift = -CGRectGetHeight(strip.bounds);
    NSUInteger pages = 0;
    for (UIView *view in strip.superview.subviews) {
        if (view == strip || ![view isKindOfClass:UIScrollView.class]) continue;
        UIScrollView *paging = (UIScrollView *)view;
        if (paging.scrollEnabled) paging.scrollEnabled = NO;
        if (paging.transform.ty != lift) paging.transform = CGAffineTransformMakeTranslation(0, lift);
        pages++;
    }
    if (lift == 0 || !pages) return YES;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"artist: tab strip hidden, %lu paging view moved up %.0f and not swiping", (unsigned long)pages, -lift); });
    return YES;
}

#pragma mark - hero

- (SGRHeroHeader *)heroFor:(UIView *)container {
    if (_hero) return _hero;
    _hero = [[SGRHeroHeader alloc] initWithFrame:container.bounds];
    [_hero bindToField:_field];
    // English until Spotify's own words are read from its header (mirror:), a moment later.
    _shuffle = [SGRGlassButton circleWithSymbol:@"shuffle" accessibilityLabel:@"Shuffle"];
    _play = [SGRGlassButton capsuleWithSymbol:@"play.fill" title:@"Play" prominent:YES];
    _follow = [SGRGlassButton capsuleWithSymbol:nil title:@"Follow" prominent:NO];
    __weak SGArtistPage *weakSelf = self;
    _shuffle.onTap = ^{ [weakSelf tapShuffle]; };
    _play.onTap = ^{ [weakSelf tapPlay]; };
    _follow.onTap = ^{ [weakSelf tapFollow]; };
    SGRActionRow *row = [[SGRActionRow alloc] initWithFrame:_hero.actionSlot.bounds];
    row.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    row.buttons = @[_shuffle, _play, _follow];
    [_hero.actionSlot addSubview:row];
    [self updatePlay];
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"artist: hero in the header container, %.0f tall", CGRectGetHeight(container.bounds)); });
    return _hero;
}

- (void)headerContainerDidLayout:(UIView *)container {
    SGRHeroHeader *hero = [self heroFor:container];
    if (container.subviews.lastObject != hero) [container addSubview:hero];
    if (!CGRectEqualToRect(hero.frame, container.bounds)) {
        hero.frame = container.bounds;
        [self applyScroll];
    }
    for (UIView *element in container.subviews) {
        for (UIView *header in element.subviews) {
            if ([header isKindOfClass:sg_imageHeaderClass]) [self stockHeaderDidLayout:header];
        }
    }
}

- (void)stockHeaderDidLayout:(UIView *)header {
    if (header.alpha != 0 || header.userInteractionEnabled || !header.accessibilityElementsHidden) {
        SGRSuppress(header);
        static dispatch_once_t once;
        dispatch_once(&once, ^{ SGLog(@"artist: Spotify's header hidden"); });
    }
    _stockHeader = header;
    // Spotify shrinks its header into the pinned band while the page scrolls, laying it out every frame;
    // what it shows does not change then, so it is read at full height only, and at most every 0.3 s with
    // one more read after a burst of layouts.
    UIView *container = header.superview.superview;
    if (!_hero || CGRectGetHeight(header.bounds) < CGRectGetHeight(container.bounds) - 1 || _mirrorScheduled) return;
    CFTimeInterval now = CACurrentMediaTime();
    if (now - _lastMirror >= 0.3) {
        _lastMirror = now;
        [self mirror:header];
        return;
    }
    [self mirrorLater:header];
}

- (void)mirrorLater:(UIView *)header {
    if (_mirrorScheduled) return;
    _mirrorScheduled = YES;
    __weak SGArtistPage *weakSelf = self;
    __weak UIView *weakHeader = header;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SGArtistPage *page = weakSelf;
        if (!page) return;
        page->_mirrorScheduled = NO;
        page->_lastMirror = CACurrentMediaTime();
        UIView *later = weakHeader;
        if (later) [page mirror:later];
    });
}

// Spotify's controls, looked for inside its header only: the music videos shelf has a header-play-button
// and the biography card a follow button of their own (10.txt).
- (void)findControlsIn:(UIView *)header {
    static char playKey, shuffleKey, followKey;
    _playControl = SGRFindByIdentifier(header, @"header-play-button", &playKey);
    UIView *shuffle = SGRFindByIdentifier(header, @"Components.UI.ShuffleButton", &shuffleKey);
    _shuffleControl = [shuffle isKindOfClass:UIControl.class] ? (UIControl *)shuffle : nil;
    UIView *follow = SGRFindByIdentifier(header, @"Curation.FollowButtonElementKit.FollowButton", &followKey);
    _followControl = [follow isKindOfClass:UIControl.class] ? (UIControl *)follow : nil;
}

- (void)mirror:(UIView *)header {
    static char titleKey, metaKey, artworkKey, exploreKey;
    NSString *title = labelTextIn(SGRFindByIdentifier(header, @"Encore.AdaptiveTitle", &titleKey));
    if (title.length) _hero.title = title;
    UILabel *meta = (UILabel *)SGRFindByIdentifier(header, @"Components.Header.UI.Metadata-internal", &metaKey);
    if ([meta isKindOfClass:UILabel.class]) _hero.meta = meta.text;

    UIImageView *artwork = nil;
    for (UIView *view in SGRFindByIdentifier(header, @"Components.Header.UI.ArtworkImage.ImageView", &artworkKey).subviews) {
        if ([view isKindOfClass:UIImageView.class]) {
            artwork = (UIImageView *)view;
            break;
        }
    }
    if (artwork != _artworkView) [self watchArtwork:artwork];

    [self findControlsIn:header];
    UIView *shuffle = _shuffleControl, *follow = _followControl;

    // The explore deck plays short videos in the header (01.txt: SPTVideoSurfaceImpl under
    // Components.UI.WatchFeedEntityExplorerButton). It goes transparent, never hidden: hiding it, though it
    // is no arranged view itself, changes the size of the button the header's Reprise OverflowStackView
    // arranges, and that stack traps in updateConstraints (crash 2026-09-17 09:30, the same trap as
    // Features/Artist/Artist.x on 2026-09-15). Spotify's whole header is transparent already.
    UIView *deck = SGRFindByIdentifier(header, @"Components.UI.WatchFeedEntityExplorerButton", &exploreKey).subviews.firstObject;
    if (deck.alpha != 0) deck.alpha = 0;

    [self mirrorControls];
    // The buttons and the photo can arrive after the header's last layout at full height (Features/Artist/
    // Artist.x watches the button row's stack for that), so a read that missed one is repeated, for a while.
    if (!(title.length && artwork && _playControl && shuffle && follow) && _missedReads < 10) {
        _missedReads++;
        [self mirrorLater:header];
    }
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"artist: header read, title %@, meta %@, artwork %@, play %@, shuffle %@, follow %@, explore deck %@",
              title.length ? @"yes" : @"no", meta.text.length ? @"yes" : @"no", artwork ? @"yes" : @"no",
              NSStringFromClass(self->_playControl.class) ?: @"missing", NSStringFromClass(shuffle.class) ?: @"missing",
              NSStringFromClass(follow.class) ?: @"missing", deck ? @"hidden" : @"missing");
    });
}

// The photo arrives after the header is built, and setting it lays nothing out, so the image view is watched.
- (void)watchArtwork:(UIImageView *)view {
    UIImageView *watched = _artworkView;
    _artworkView = nil;
    if (watched) {
        @try {
            [watched removeObserver:self forKeyPath:@"image" context:&kArtworkContext];
        } @catch (NSException *exception) {
            SGLog(@"artist: artwork observation was already gone (%@)", exception.reason);
        }
    }
    if (!view) return;
    _artworkView = view;
    [view addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionInitial context:&kArtworkContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != &kArtworkContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    UIImage *image = [object isKindOfClass:UIImageView.class] ? ((UIImageView *)object).image : nil;
    if (!image || image == _image) return;
    _image = image;
    [_hero setImage:image animated:YES];
    [_field setArtwork:image identity:nil animated:YES];
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"artist: hero image %.0fx%.0f@%.0f", image.size.width, image.size.height, image.scale); });
}

#pragma mark - actions

- (void)mirrorControls {
    // Spotify builds a control anew when its state changes (a follow), which lets go of the old one.
    UIView *header = _stockHeader;
    if (header && (!_playControl || !_shuffleControl || !_followControl)) [self findControlsIn:header];
    UIControl *shuffle = _shuffleControl, *follow = _followControl;
    _shuffle.enabled = shuffle != nil;
    _follow.enabled = follow != nil;
    _play.enabled = _playControl != nil;
    if (shuffle) {
        _shuffle.on = shuffleDotShown(shuffle);
        if (shuffle.accessibilityLabel.length) _shuffle.accessibilityLabel = shuffle.accessibilityLabel;
    }
    NSString *followTitle = labelTextIn(follow) ?: follow.accessibilityLabel;
    if (followTitle.length) [_follow setTitle:followTitle animated:YES];
    [self updatePlay];
}

// Playing means this artist's context is the player's and it is not paused; the glyph follows the
// player, the title is Spotify's own for its play button.
- (void)updatePlay {
    SPTPlayerState *state = SGRPlayerState();
    BOOL playing = state.isPlaying && !state.isPaused && [SGRURIString(state.contextURI) isEqualToString:_uri];
    [_play setSymbol:playing ? @"pause.fill" : @"play.fill" animated:YES];
    NSString *title = buttonIn(_playControl).accessibilityLabel;
    [_play setTitle:title.length ? title : playing ? @"Pause" : @"Play" animated:YES];
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    if (!_hero) return;
    [self mirrorControls];
    [self refreshSoon];
}

// Spotify's controls change their look a moment after the tap, once the player or the follow state answers.
- (void)refreshSoon {
    __weak SGArtistPage *weakSelf = self;
    for (NSNumber *delay in @[@0.35, @1.2]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf mirrorControls];
        });
    }
}

- (void)tapPlay {
    UIView *control = _playControl;
    BOOL direct = [control respondsToSelector:@selector(uiButtonTapped)];
    BOOL fired = direct;
    if (direct) [(id<SGArtistPlayButton>)control uiButtonTapped];
    else fired = fire(buttonIn(control));
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SPTPlayerState *state = SGRPlayerState();
        SGLog(@"artist: play %@ (%@), player context %@ paused %d", fired ? @"fired" : @"fired nothing", direct ? @"uiButtonTapped" : @"its button",
              SGRURIString(state.contextURI), state.isPaused);
    });
    [self refreshSoon];
}

- (void)tapShuffle {
    UIControl *control = _shuffleControl;
    BOOL before = control ? shuffleDotShown(control) : NO;
    BOOL fired = fire(control);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        __weak UIControl *weakControl = control;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIControl *later = weakControl;
            SGLog(@"artist: shuffle %@, dot %d then %d", fired ? @"fired" : @"fired nothing", before, later ? shuffleDotShown(later) : -1);
        });
    });
    [self refreshSoon];
}

- (void)tapFollow {
    UIControl *control = _followControl;
    NSString *before = labelTextIn(control);
    BOOL fired = fire(control);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        __weak UIControl *weakControl = control;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIControl *later = weakControl;
            SGLog(@"artist: follow %@, label \"%@\" then \"%@\", selected %d", fired ? @"fired" : @"fired nothing", before, labelTextIn(later), later.isSelected);
        });
    });
    [self refreshSoon];
}

@end

SGArtistPage *SGArtistPageOf(UIView *view, BOOL *pending) {
    if (pending) *pending = NO;
    UIView *template = view;
    while (template && ![template isKindOfClass:sg_templateClass]) template = template.superview;
    if (!template) {
        if (pending) *pending = view.window == nil;
        return nil;
    }
    id known = objc_getAssociatedObject(template, &kPageKey);
    if (known) return known == NSNull.null ? nil : known;
    NSString *uri = SGRURIString(SGRPageURI(template));
    if (!uri) {
        if (pending) *pending = YES;
        static dispatch_once_t once;
        dispatch_once(&once, ^{ SGLog(@"artist: a creator page has no URI yet, asked again on its next layout"); });
        return nil;
    }
    if (![uri hasPrefix:@"spotify:artist:"]) {
        objc_setAssociatedObject(template, &kPageKey, NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return nil;
    }
    SGArtistPage *page = [[SGArtistPage alloc] initWithURI:uri template:template];
    objc_setAssociatedObject(template, &kPageKey, page, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return page;
}

%hook _TtC32CreativeWorkPlatform_TemplateKit12TemplateView
- (void)layoutSubviews {
    %orig;
    [SGArtistPageOf((UIView *)self, NULL) templateDidLayout:(UIView *)self];
}
%end

%hook _TtC32CreativeWorkPlatform_TemplateKitP33_07D2BCE376DED6F379FF5AAB5402E56315HeaderContainer
- (void)layoutSubviews {
    %orig;
    [SGArtistPageOf((UIView *)self, NULL) headerContainerDidLayout:(UIView *)self];
}
%end

// Hidden from its first moment in the window, before its first layout could show Spotify's own header.
%hook _TtC35CreativeWorkPlatform_ImageHeaderKit15ImageHeaderView
- (void)didMoveToWindow {
    %orig;
    UIView *header = (UIView *)self;
    if (header.window) [SGArtistPageOf(header, NULL) stockHeaderDidLayout:header];
}

- (void)layoutSubviews {
    %orig;
    [SGArtistPageOf((UIView *)self, NULL) stockHeaderDidLayout:(UIView *)self];
}
%end

// The strip is laid out with the tabs' controller view, which holds it (01.txt: tabsViewAccessibilityID).
%hook _TtC28CreativeWorkPlatform_TabsKit16TabBarController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *view = ((UIViewController *)self).view;
    SGArtistPage *page = SGArtistPageOf(view, NULL);
    if (!page) return;
    if (![page hideTabsIn:view] && view.superview) [page hideTabsIn:view.superview];
}
%end

%ctor {
    // No remote-config flags are forced for this page. Forcing the creator flags (the Video tab, the video,
    // collaborator and facts sections off, the context menu moved into the navigation bar) built a header
    // the clean trees never showed, and the header's Reprise OverflowStackView trapped in updateConstraints
    // on every artist page (crashes 2026-09-17 09:30, 09:44, 09:48, from the header's didMoveToWindow and
    // layoutSubviews). The list's allowlist removes those sections as Spotify builds them.
    SGRedesignRegisterRows(@"artist", ^NSArray<SGModRow *> *{
        return @[SGHideRow(@"Hide songs you liked", @"The row of this artist's songs in your Liked Songs", SGKeyRedesignArtistHideLikedSongs)];
    });
    if (!SGRedesignOn(@"artist")) return;
    sg_templateClass = NSClassFromString(@"_TtC32CreativeWorkPlatform_TemplateKit12TemplateView");
    sg_imageHeaderClass = NSClassFromString(@"_TtC35CreativeWorkPlatform_ImageHeaderKit15ImageHeaderView");
    %init;
    SGRequireClasses(@[
        @"_TtC32CreativeWorkPlatform_TemplateKit12TemplateView",
        @"_TtC32CreativeWorkPlatform_TemplateKitP33_07D2BCE376DED6F379FF5AAB5402E56315HeaderContainer",
        @"_TtC35CreativeWorkPlatform_ImageHeaderKit15ImageHeaderView",
        @"_TtC28CreativeWorkPlatform_TabsKit16TabBarController",
        @"_TtC28EncoreConsumerMobile_BaseKit14PlayButtonView",
    ]);
}
