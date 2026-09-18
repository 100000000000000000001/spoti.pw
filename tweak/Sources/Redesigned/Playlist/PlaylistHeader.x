// Playlist redesign: the header the Music app gives a playlist (iOS 26.4). The cover runs full bleed across
// the top of the page and dissolves into the page's colour; the title, the creator and the length are centred
// on the bottom of that dissolve; under them one row -- shuffle, a white Play capsule, and save (someone
// else's playlist) or download (one's own, Liked Songs) -- and the description last.
//
// Tree (trees/clean/playlist/01.txt:640-869). Spotify's header is id=PL.Header, and at rest its
// HeaderContentLayout starts at the very top of the page. It holds exactly two things:
//
//     Components.Header.UI.ArtworkImage   a ShadowContainer, the cover square, centred at {80, 68} 243x243
//     the block                           a plain UIView at {0, 327} 386x178: a column of title, description,
//                                         creator row and length, and under it the action row
//
// Nothing is measured from what the header shows: -[SPTFreeTierPlaylistEncoreHeaderViewController update]
// counts a stored fullHeaderHeight and pins headerViewHeightConstraint to it. So the redesign changes no
// height: the cover's square is where the full bleed picture goes, and the block keeps its place, its size
// and its fading as the header collapses.
//
// What is in the block is the redesign's own (the Kit's SGRHeaderInfo), not Spotify's rearranged. Moving Spotify's
// column and controls meant answering every layout pass of theirs -- stacks re-arranging, Auto Layout putting
// frames back, buttons flashing where Spotify wanted them -- so Spotify's contents of the block are concealed
// whole and one view of the redesign's own is drawn in their place, which nothing of Spotify's lays out. It
// reads what it shows from the page's view model (FTPViewModelImplementation: the name, the description,
// whose playlist it is; device 2026-09-18) and from Spotify's concealed labels where the model has no getter
// (the creator, and the length line, already in the app's language). Its buttons draw Spotify's glyphs and
// fire Spotify's own concealed controls, so every action, state and language stays Spotify's.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Playlist.h"
#import <objc/message.h>

// How much of the cover's height the dissolve into the field covers, and the scrim over the top of it that
// keeps the status bar and the back button legible on a bright picture.
static const CGFloat kDissolve = 0.46, kTopScrim = 140, kTopScrimAlpha = 0.28;
// A header whose cover square is smaller than this is one mid collapse or mid load, not one to measure
// the hero from; and an artwork view narrower than this is a placeholder glyph rather than the cover.
static const CGFloat kMinHero = 120, kMinCover = 80;

static char kCoverKey, kMetaKey, kPlayKey, kLayoutKey, kToolbarKey, kScrimKey, kBarScrimKey;
static char kShuffleKey, kAddKey, kDownloadKey, kInfoKey, kBlockHeightKey, kBlockWatchedKey;
static char kHeroKey, kHeroHeightKey, kCoverWatchedKey;

#pragma mark - finding things

@interface SGRWeakView : NSObject
@property (nonatomic, weak) UIView *view;
@end
@implementation SGRWeakView
@end

UIViewController *SGRPlaylistHeaderOf(UIView *view) {
    for (UIResponder *r = view; r; r = r.nextResponder) {
        if (![r isKindOfClass:UIViewController.class]) continue;
        return [NSStringFromClass(r.class) containsString:@"FreeTierPlaylist"] ? (UIViewController *)r : nil;
    }
    return nil;
}

// Invisible for good, whatever Spotify does to it. It fades its cover square and its colour wash back in
// from the scroll itself (trees/continuous/1.txt, 2026-09-17), which a hidden layer shrugs off; but pressing
// Play reconfigures the header, and that shows the wash, the find bar and the play disc again with
// -setHidden:NO, which writes the layer's own hidden and so undid this: the wash came back over the
// picture as a dark band and the green disc beside the capsule (trees/continuous/1.txt, 2026-09-18).
//
// So two things, each for what the other cannot do. `hidden` on the layer costs nothing while it holds --
// the layer is not drawn at all -- and, unlike -[UIView setHidden:], tells neither KVO nor the stack views,
// which is what makes it safe on Spotify's Encore layouts. An empty mask is what holds when Spotify shows
// the view anyway: nothing Spotify does to these views touches a mask, and a layer masked by nothing draws
// nothing. The album page found the same (Album/AlbumHeader.x) and masks its gradients.
static void conceal(UIView *view) {
    if (!view) return;
    if (!view.layer.hidden) view.layer.hidden = YES;
    if (!view.layer.mask) view.layer.mask = [CALayer layer];
    if (view.userInteractionEnabled) view.userInteractionEnabled = NO;
    view.accessibilityElementsHidden = YES;
}

static UIView *firstOfClass(UIView *root, Class wanted) {
    __block UIView *found = nil;
    SGForEachView(root, ^(UIView *v) {
        if (!found && [v isKindOfClass:wanted]) found = v;
    });
    return found;
}

#pragma mark - the cover, full bleed

// The picture across the top of the page with the field showing through the bottom of it. Two gradients
// rather than a mask or a blur: a scrim over the top for the status bar, and under it a fade from the
// picture to the very colour the page's field is drawing, so the two meet with nothing to see.
@interface SGRPlaylistHero : UIView
@property (nonatomic, readonly) UIImageView *picture;
@property (nonatomic, copy) UIColor *fieldColor;
@property (nonatomic) CGFloat coverPixels;   // the widest copy of the artwork it has been shown
@end

@implementation SGRPlaylistHero {
    CAGradientLayer *_scrim, *_dissolve;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    self.clipsToBounds = YES;

    _picture = [[UIImageView alloc] initWithFrame:self.bounds];
    _picture.contentMode = UIViewContentModeScaleAspectFill;
    _picture.clipsToBounds = YES;
    _picture.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_picture];

    // Above the picture's own layer whatever else is added to the view later.
    _scrim = [CAGradientLayer layer];
    _scrim.zPosition = 1;
    _scrim.colors = @[(id)[UIColor colorWithWhite:0 alpha:kTopScrimAlpha].CGColor, (id)UIColor.clearColor.CGColor];
    [self.layer addSublayer:_scrim];

    _dissolve = [CAGradientLayer layer];
    _dissolve.zPosition = 2;
    [self.layer addSublayer:_dissolve];
    self.fieldColor = SGRNeutralField();
    // The colour is read off the main thread, so it can land after the last layout pass of the page.
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(sgr_fieldColorDidChange)
                                               name:SGRFieldColorDidChangeNotification object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)sgr_fieldColorDidChange {
    if (self.superview) self.fieldColor = SGRPlaylistFieldColor(self);
}

- (void)setFieldColor:(UIColor *)color {
    if (!color || [_fieldColor isEqual:color]) return;
    _fieldColor = [color copy];
    // The clear end is the same colour with no alpha rather than +clearColor, so the fade keeps its hue
    // instead of going through grey.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _dissolve.colors = @[(id)[color colorWithAlphaComponent:0].CGColor,
                         (id)[color colorWithAlphaComponent:0.72].CGColor,
                         (id)color.CGColor];
    _dissolve.locations = @[@0, @0.62, @1];
    [CATransaction commit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _scrim.frame = CGRectMake(0, 0, bounds.size.width, MIN(kTopScrim, bounds.size.height));
    CGFloat fade = round(bounds.size.height * kDissolve);
    _dissolve.frame = CGRectMake(0, bounds.size.height - fade, bounds.size.width, fade);
    [CATransaction commit];
}

@end

// The cover Spotify loaded, read from the image view of its artwork square.
static UIImageView *coverImageIn(UIView *cover) {
    __block UIImageView *found = nil;
    SGForEachView(cover, ^(UIView *v) {
        if (found || ![v isKindOfClass:UIImageView.class]) return;
        UIImageView *image = (UIImageView *)v;
        if (image.image && image.bounds.size.width >= kMinCover) found = image;
    });
    return found;
}

// Spotify loads the artwork at the size the cover square is asking for, and the square shrinks as the
// header collapses: scrolled down it swapped a 105px copy in for the 254px one and the picture across the
// top of the page went soft with it (trees/continuous/2.txt, 2026-09-17). So a copy is taken only while the
// square is still at full size, which is the only time Spotify asks for one worth showing.
static void showCover(SGRPlaylistHero *hero, UIImageView *view, UIView *layout) {
    UIImage *image = view.image;
    if (!image || view.bounds.size.width < kMinHero) return;

    hero.coverPixels = image.size.width;
    if (hero.picture.image != image) hero.picture.image = image;
    SGRPlaylistSetArtwork(layout, image);
}

// The hero belongs in the plane Spotify's own colour wash is drawn on: that plane keeps its full height and
// slides up out of the clipping view as the header collapses, and the container above it fades it out as the
// navigation bar takes over (trees/continuous/2.txt: the wash at {0, -364} 402x474 inside a 110pt container
// at a=0.00). So the picture needs no help to move -- Core Animation carries it with the plane, in the same
// frame, with nothing to recompute and so nothing to flicker.
//
// Which is the whole design: the hero is measured once, when the header is first laid out whole, and its
// frame never changes again. Everything else the page does to it -- the collapse, the snap, the bounce at
// the top -- is the plane's movement, which is Spotify's to make and ours to sit still inside. Reading the
// header's geometry on every frame instead is what made it flicker: the numbers it is built from move under
// their own animations, and a redesign reading them is always a frame behind.
//
// Its height is where the header's text begins, taken in the plane's own space, and a little past. Below that the page's field
// is already drawing the very colour the picture dissolves into, so the hero simply stops there: pulled down
// past the top, where Spotify moves its text down and leaves a gap, that gap is the same colour and there is
// no seam to see.
static void applyHero(UIView *layout, UIView *cover, UIView *plane, UIView *block, CGFloat reach) {
    if (!plane || !block) return;
    SGRPlaylistHero *hero = objc_getAssociatedObject(plane, &kHeroKey);
    if (!hero) {
        hero = [[SGRPlaylistHero alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(plane, &kHeroKey, hero, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (hero.superview != plane) [plane insertSubview:hero atIndex:0];
    else if (plane.subviews.firstObject != hero) [plane sendSubviewToBack:hero];

    // The top of the block in the layout's own space, which is the plane's own while the header is whole:
    // both sit at the top of the clipping view, and the 134pt the page is pulled down by moves them
    // together. So it is the height the picture wants, and the only one that does not move under the
    // header's animations.
    //
    // The furthest down it has been, rather than where it is: a header still loading puts the block higher
    // than it will end up (267 against the 338 it settled at, trees/continuous 2026-09-17, which left the
    // picture stopping short with a band of bare field between it and the title), and a header collapsing
    // climbs it out of its place altogether. Both are answered by only ever letting it grow, which settles
    // once the cover and the description are in and never moves again.
    CGFloat height = [objc_getAssociatedObject(hero, &kHeroHeightKey) doubleValue];
    CGFloat top = CGRectGetMinY(block.frame);
    if (top > height + 0.5) {
        height = top;
        objc_setAssociatedObject(hero, &kHeroHeightKey, @(height), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SGLog(@"redesign playlist: hero %.0fpt across the top of the plane", height);
    }
    if (height < kMinHero) return;
    // On past the block's top by `reach`, so the title sits on the bottom of the dissolve the way the Music app
    // sets it on the picture. `reach` comes from the block at rest (applyHeader), so the frame still does not
    // move while the header does.
    CGFloat bottom = MAX(kMinHero, round(height + reach));
    CGRect frame = CGRectMake(0, 0, plane.bounds.size.width, bottom);
    if (!CGRectEqualToRect(hero.frame, frame)) hero.frame = frame;
    hero.fieldColor = SGRPlaylistFieldColor(layout);

    UIImageView *source = coverImageIn(cover);
    showCover(hero, source, layout);
    // The cover loads after the header is laid out, and a new image lays nothing out again.
    if (source && !objc_getAssociatedObject(source, &kCoverWatchedKey)) {
        objc_setAssociatedObject(source, &kCoverWatchedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak SGRPlaylistHero *weakHero = hero;
        __weak UIView *weakLayout = layout;
        SGRObserveImage(source, ^(UIImageView *view) {
            if (weakHero && weakLayout) showCover(weakHero, view, weakLayout);
        });
    }
    conceal(cover);
}

#pragma mark - the block, the redesign's own

// The page's view model: the header controller's defaultHeaderViewModel, FTPViewModelImplementation on every
// playlist, Liked Songs and a shared playlist alike (device, 2026-09-18). Its getters are plain ObjC --
// playlistName and playlistDescription @, isOwnedBySelf B, formatListType @ (Spotify 9.1.78) -- and each is
// checked before it is called, so a Spotify without one shows Spotify's text for it rather than crashing.
static id viewModelOf(UIViewController *headerVC) {
    SEL controllerSel = NSSelectorFromString(@"headerController"), modelSel = NSSelectorFromString(@"defaultHeaderViewModel");
    if (![headerVC respondsToSelector:controllerSel]) return nil;
    id controller = ((id (*)(id, SEL))objc_msgSend)(headerVC, controllerSel);
    if (![controller respondsToSelector:modelSel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(controller, modelSel);
}

static NSString *modelString(id model, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    if (![model respondsToSelector:sel]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(model, sel);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static BOOL modelFlag(id model, NSString *name, BOOL fallback) {
    SEL sel = NSSelectorFromString(name);
    if (![model respondsToSelector:sel]) return fallback;
    return ((BOOL (*)(id, SEL))objc_msgSend)(model, sel);
}

// A description is HTML: links to other playlists as <a> and entities for quotes and ampersands.
static NSString *plainText(NSString *html) {
    if (!html.length) return nil;
    static NSRegularExpression *tags;
    if (!tags) tags = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:NULL];
    NSMutableString *text = [[tags stringByReplacingMatchesInString:html options:0 range:NSMakeRange(0, html.length)
                                                       withTemplate:@""] mutableCopy];
    NSDictionary<NSString *, NSString *> *entities = @{@"&amp;": @"&", @"&quot;": @"\"", @"&#x27;": @"'", @"&#39;": @"'",
                                                       @"&lt;": @"<", @"&gt;": @">", @"&nbsp;": @" "};
    for (NSString *entity in entities) {
        [text replaceOccurrencesOfString:entity withString:entities[entity] options:0 range:NSMakeRange(0, text.length)];
    }
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length ? trimmed : nil;
}

static NSString *firstText(UIView *root, UIView *skip) {
    __block NSString *found = nil;
    SGForEachView(root, ^(UIView *v) {
        if (found || ![v isKindOfClass:UILabel.class] || (skip && [v isDescendantOfView:skip])) return;
        NSString *text = [((UILabel *)v).text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (text.length > 1) found = text;
    });
    return found;
}

// The creator is on no getter of the page's model; Spotify's own creator row has the name beside the facepile
// (its avatars, whose initial is a one-letter label of its own: "D | Darkk" on the device, 2026-09-18). A
// shared playlist's reads "Darkk" as well, with the others in the facepile. Looked for no further up than the
// facepile's own row, where the title would be the next label found.
static NSString *creatorIn(UIView *block) {
    __block UIView *facepile = nil;
    SGForEachView(block, ^(UIView *v) {
        if (!facepile && [NSStringFromClass(v.class) containsString:@"FacepileView"]) facepile = v;
    });
    UIView *row = facepile.superview;
    for (NSUInteger level = 0; row && row != block && level < 3; level++, row = row.superview) {
        NSString *name = firstText(row, facepile);
        if (name) return name;
    }
    return nil;
}

// The length line, as Spotify words it in the app's language: "8 saves • 41h 14m", "1 038 songs".
static NSString *lengthIn(UIView *block) {
    return firstText(SGRFindByIdentifier(block, @"Components.Header.UI.Metadata", &kMetaKey), nil);
}

// What the playlist's header shows: the name and the description from the page's model, the creator and the
// length from Spotify's concealed labels, and on Play's right save for someone else's playlist, download for
// one's own and for Liked Songs, which Spotify reports as neither owned nor unsaved (isOwnedBySelf NO,
// formatListType liked-songs).
static void showPlaylist(SGRHeaderInfo *info, UIView *block, UIView *root, id model) {
    NSString *title = modelString(model, @"playlistName") ?: firstText(block, nil);
    [info showTitle:title creator:creatorIn(block) length:lengthIn(block)
              about:plainText(modelString(model, @"playlistDescription"))];

    BOOL liked = [modelString(model, @"formatListType") isEqualToString:@"liked-songs"];
    BOOL own = modelFlag(model, @"isOwnedBySelf", YES) || liked;
    UIView *shuffle = SGRFindByIdentifier(block, @"Components.UI.ShuffleButton", &kShuffleKey);
    UIView *play = SGRFindByIdentifier(root, @"header-play-button", &kPlayKey);
    UIView *save = own ? nil : SGRFindByIdentifier(block, @"Components.UI.AddToButton", &kAddKey);
    UIView *download = save ? nil : SGRFindByIdentifier(block, @"DownloadButton.Granular*", &kDownloadKey);
    [info showShuffle:shuffle play:play trailing:save ?: download
     trailingFallback:[UIImage systemImageNamed:save ? @"plus" : @"arrow.down"] playColor:SGRPlaylistFieldColor(info)];
    // Only what the button draws goes: a concealed layer still sends the actions the capsule fires.
    conceal(play);

    static BOOL logged;
    if (!logged && info.window && (title || play)) {
        logged = YES;
        SGLog(@"redesign playlist: own block \"%@\" by %@, \"%@\"; shuffle %@, play %@, %@; model %@",
              title, creatorIn(block) ?: @"nobody", lengthIn(block) ?: @"no length", shuffle ? @"found" : @"missing",
              play ? @"found" : @"missing", save ? @"save" : (download ? @"download" : @"nothing on the right"),
              model ? NSStringFromClass([model class]) : @"missing");
    }
}

// The block's own content goes, whole, and the redesign's takes its place. Spotify adds to the block as the page
// loads and shows parts of it again when Play is pressed, so everything of Spotify's in it is concealed on every
// pass and again from the block's own pass; concealing is idempotent and costs nothing once done.
static SGRHeaderInfo *applyInfo(UIView *block, UIView *headerRoot, UIViewController *headerVC) {
    // One per page, kept on the header's root: if Spotify ever hands over another block, the same view moves
    // into it rather than a second one being drawn beside the first.
    SGRHeaderInfo *info = objc_getAssociatedObject(headerRoot, &kInfoKey);
    if (!info) {
        info = [[SGRHeaderInfo alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(headerRoot, &kInfoKey, info, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (info.superview != block) {
        if (info.superview) SGLog(@"redesign playlist: the block moved, %@ -> %@", NSStringFromCGRect(info.superview.frame), NSStringFromCGRect(block.frame));
        [block addSubview:info];
    }
    else if (block.subviews.lastObject != info) [block bringSubviewToFront:info];
    for (UIView *sub in block.subviews) {
        if (sub != info) conceal(sub);
    }
    // The page's width, centred on the screen: Spotify's block is 16pt narrower than the page (386 of 402).
    CGFloat x = -[block convertPoint:CGPointZero toView:headerRoot].x;
    CGRect frame = CGRectMake(round(x), 0, headerRoot.bounds.size.width, block.bounds.size.height);
    if (!CGRectEqualToRect(info.frame, frame)) info.frame = frame;
    showPlaylist(info, block, headerRoot, viewModelOf(headerVC));

    if (!objc_getAssociatedObject(block, &kBlockWatchedKey)) {
        objc_setAssociatedObject(block, &kBlockWatchedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIView *weakRoot = headerRoot;
        __weak UIViewController *weakVC = headerVC;
        SGRObserveLayout(block, ^(UIView *view) {
            // A block the view has since left is Spotify's to lay out alone.
            if (!weakRoot || !weakVC || [objc_getAssociatedObject(weakRoot, &kInfoKey) superview] != view) return;
            applyInfo(view, weakRoot, weakVC);
        });
    }
    return info;
}


#pragma mark - the header's pass

// Find on this page and Sort sit in a header view of their own above the cover, invisible until the page is
// scrolled; the Music app has neither.
static void applyToolbar(UIView *headerRoot) {
    UIView *toolbar = SGRFindByIdentifier(headerRoot, @"Components.Header.UI.Toolbar.Content", &kToolbarKey);
    for (UIView *v = toolbar; v && v != headerRoot; v = v.superview) {
        if (![NSStringFromClass(v.class) containsString:@"HeaderView"]) continue;
        conceal(v);
        break;
    }
}

// Two scrims Spotify fades in under the navigation bar as the page scrolls, each tinted with its own colour
// for the page rather than the field's: LiquidGlass.gradientContainer (124pt, a child of HeaderLayout) and
// the HeaderNavigationBar's GradientView. On Liked Songs the first is Spotify's blue, a band across the top
// of a black page (trees/continuous/2.txt, 2026-09-18). UIKit's own scroll edge effect is still there under
// the bar and keeps the back button legible, as on Home, Search and Library. Concealed rather than faded:
// Spotify writes their alpha on every step of the scroll, and the navigation bar's with -setHidden:.
static void applyScrims(UIView *headerRoot) {
    conceal(SGRFindByIdentifier(headerRoot, @"LiquidGlass.gradientContainer", &kScrimKey));
    // A concealed view stays concealed, so the bar is looked for until it is found and then never again:
    // the header lays out on every step of its collapse.
    if (objc_getAssociatedObject(headerRoot, &kBarScrimKey)) return;
    static Class bar;
    if (!bar) bar = NSClassFromString(@"_TtC28EncoreConsumerMobile_BaseKit19HeaderNavigationBar");
    UIView *navigation = firstOfClass(headerRoot, bar);
    for (UIView *sub in navigation.subviews) {
        if (![NSStringFromClass(sub.class) containsString:@"GradientView"]) continue;
        conceal(sub);
        objc_setAssociatedObject(headerRoot, &kBarScrimKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// Spotify's colour wash goes, so the page's field shows through, and the plane it was drawn on is handed
// back: it is where the hero belongs (applyHero).
static UIView *applyBackground(UIView *layout) {
    UIView *container = nil;
    for (UIView *v = layout.superview; v && !container; v = v.superview) {
        for (UIView *sub in v.subviews) {
            if ([sub.accessibilityIdentifier isEqualToString:@"_backgroundViewContainer"]) container = sub;
        }
    }
    UIView *plane = container.subviews.firstObject;
    SGForEachView(container, ^(UIView *v) {
        if ([NSStringFromClass(v.class) containsString:@"GradientView"]) conceal(v);
    });
    return plane;
}

// The layout holds the cover square and, under it, the block of text and controls: the one child nearly as
// wide as the page. Taken by width, not by being lowest: Liked Songs' layout also holds a 45pt slot for its
// icon, which while the page loads sits below the block, and taken for it the header was drawn twice, once
// in the slot and once in the block (device, 2026-09-18).
static UIView *blockIn(UIView *layout, UIView *cover) {
    UIView *block = nil;
    CGFloat wide = layout.bounds.size.width * 0.6;
    for (UIView *sub in layout.subviews) {
        if (sub == cover || [sub isKindOfClass:SGRPlaylistHero.class] || sub.bounds.size.width < wide) continue;
        if (!block || CGRectGetMinY(sub.frame) > CGRectGetMinY(block.frame)) block = sub;
    }
    return block;
}

static void applyHeader(UIView *layout) {
    UIViewController *headerVC = SGRPlaylistHeaderOf(layout);
    UIView *headerRoot = headerVC.viewIfLoaded;
    if (!headerRoot) return;

    UIView *cover = SGRFindByIdentifier(layout, @"Components.Header.UI.ArtworkImage", &kCoverKey);
    UIView *block = blockIn(layout, cover);
    if (!block) return;

    UIView *plane = applyBackground(layout);
    applyToolbar(headerRoot);
    applyScrims(headerRoot);
    SGRHeaderInfo *info = applyInfo(block, headerRoot, headerVC);

    // How far into the block the picture reaches: to where the content's top is at rest, plus the title and
    // the creator. The block's height at rest is the tallest it has been -- collapsing shrinks it (136 against
    // 178, trees/continuous/2.txt) and loading the description grows it -- so like the hero's top it only grows,
    // and the picture does not change size while the header moves.
    CGFloat rest = MAX([objc_getAssociatedObject(block, &kBlockHeightKey) doubleValue], block.bounds.size.height);
    objc_setAssociatedObject(block, &kBlockHeightKey, @(rest), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGFloat reach = rest - SGRHeaderInfoBottom - [info contentHeightForWidth:info.bounds.size.width] + SGRHeaderInfoTitleRise;
    if (cover) applyHero(layout, cover, plane, block, reach);
}


// The content layout of the page `root` belongs to, kept weakly on it: the header lays out on every step of
// its collapse and a walk of its tree each time would be the redesign's own cost.
static UIView *layoutIn(UIView *root) {
    if (!root) return nil;
    SGRWeakView *box = objc_getAssociatedObject(root, &kLayoutKey);
    UIView *layout = box.view;
    if (layout && [layout isDescendantOfView:root]) return layout;
    static Class content;
    if (!content) content = NSClassFromString(@"_TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout");
    layout = firstOfClass(root, content);
    if (!layout) return nil;
    if (!box) {
        box = [SGRWeakView new];
        objc_setAssociatedObject(root, &kLayoutKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    box.view = layout;
    return layout;
}

%hook _TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout
- (void)layoutSubviews {
    %orig;
    if (SGRPlaylistHeaderOf((UIView *)self)) applyHeader((UIView *)self);
}
%end

// The header's own pass catches the parts that fade in rather than being laid out: the find bar, and the
// action buttons as they arrive. The scroll's is where what Spotify fades back in is taken again.
// The play button arrives in the header's foreground plane after the row that replaces it has been laid
// out, so a page opening showed Spotify's green disc in the corner until something else laid the header out
// (device, 2026-09-17). Its own pass is where it goes, and the class is Spotify's own so nothing else pays
// for the check.
%hook _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView
- (void)layoutSubviews {
    %orig;
    UIView *button = (UIView *)self;
    if (button.layer.hidden || ![button.accessibilityIdentifier isEqualToString:@"header-play-button"]) return;
    if (SGRPlaylistHeaderOf(button)) conceal(button);
}
%end

%hook SPTFreeTierPlaylistEncoreHeaderViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *layout = layoutIn(((UIViewController *)self).viewIfLoaded);
    if (layout) applyHeader(layout);
}

// What the page's model says changes without a layout pass of the header's: the saves count comes in after the
// page opens (0, then 4647, device 2026-09-18), and a Save or an edit to the name updates it again.
- (void)update {
    %orig;
    UIView *layout = layoutIn(((UIViewController *)self).viewIfLoaded);
    if (layout) applyHeader(layout);
}

%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[
        @"_TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout",
        @"SPTFreeTierPlaylistEncoreHeaderViewController",
        @"_TtC28EncoreConsumerMobile_BaseKit14PlayButtonView",
    ]);
}
