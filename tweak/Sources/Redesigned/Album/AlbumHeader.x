// Album redesign: the header the Music app gives an album. The cover runs full bleed across the top of the
// page and dissolves into the field under it, with no seam and no card; the title, the artist and the kind
// and date are centred under it; and one row of glass controls sits below them -- shuffle, a prominent Play
// capsule, add, and more where Spotify still keeps it in the page.
//
// Tree (trees/clean/album/01.txt:39-152). The header is one element of the page's scrolling stack,
// id=CreativeWorkPlatform.Components.UI.CreativeWorkHeader, and everything in it is laid out by stack views
// down a chain of four:
//
//     UIView {0, 78}                     the top inset, the status bar and the navigation bar's room
//       UIStackView                      the two groups
//         UIView 402x321                 the top group
//           UIStackView                  the cover row, a spacer, and the title block
//             UIView 402x248             ArtWorkElement.WithCoverArt, the cover square centred in it
//             UIView {0, 264} 215x57     the title block, its own stack inset 16pt from the leading edge:
//                                        TitleRow, and ParentRow, the artist with a facepile
//         UIView {0, 329} 402x71         the bottom group
//           UIStackView                  the metadata row and the action row
//             UIView 402x15              Components.UI.MetadataRow: the kind and the date
//             UIStackView 206x48         explore, add, download and more
//
// Whose layout pass. A view lays its children out, so a frame set from an ancestor's layoutSubviews is the
// one that is overwritten a moment later: each view moved here is taken again from a watch on its own
// parent's pass (the Kit's SGRObserveLayout), and the header's pass only finds them and starts the watch.
// Only plain UIKit classes can be watched, which every one of those stacks is; Spotify's own Swift views
// further down are never moved, only read.
//
// Centring costs width. A view moved to the middle of the page but left inside a parent that hugs its
// content is drawn there and takes no touches there, so the title block and the action row are widened to
// the page first and their contents centred inside them. Nothing else about the header's geometry changes:
// its height is the element framework's, measured from what it holds, and the page collapses, snaps and
// scrolls exactly as Spotify laid it out.
//
// Play and shuffle are not in the header. The album page floats them over the page, pinned to the top
// trailing corner outside the scroll (01.txt:1431, :1436), where a frame of the header's cannot reach them:
// they are concealed where they are and the row carries the Kit's stand-ins, which draw their glyph and
// fire them. Every other control of Spotify's stays its own, moved by frame and never rebuilt.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Album.h"

// How much of the cover's height the dissolve into the field covers, and the scrim over the top of it that
// keeps the status bar and the back button legible on a bright picture. The playlist's numbers: one page.
static const CGFloat kDissolve = 0.46, kTopScrim = 140, kTopScrimAlpha = 0.28;
// A header whose text begins nearer the top than this is one mid load, not one to measure the hero from;
// and an artwork view narrower than this is a placeholder glyph rather than the cover.
static const CGFloat kMinHero = 120, kMinCover = 80;

static char kHeaderKey, kCoverKey, kTitleKey, kParentKey, kMetaKey, kAddKey, kMoreKey, kPlayKey, kShuffleKey;
static char kGlassKey, kHeroKey, kHeroHeightKey, kCapsuleKey, kMirrorKey, kCoverWatchedKey;
static char kHeaderWatchedKey, kGroupWatchedKey, kBlockWatchedKey, kTitleWatchedKey;
static char kBottomWatchedKey, kActionsWatchedKey, kMetaWatchedKey;

#pragma mark - moving Spotify's views

// Invisible for good. Spotify fades the header and the two floating controls by alpha as the page scrolls,
// so a redesign that answers with alpha is in a fight it loses a frame of on every scroll. `hidden` on the
// layer cannot be undone by a write to alpha, costs nothing per frame, and, unlike -[UIView setHidden:],
// tells neither KVO nor the stack views of it, which is what makes it safe on Spotify's Encore layouts.
static void conceal(UIView *view) {
    if (!view) return;
    if (!view.layer.hidden) view.layer.hidden = YES;
    view.accessibilityElementsHidden = YES;
}

// Alpha 0, no touches, hidden from accessibility, set again on every pass: for the buttons of the action
// row, which Spotify arranges in a stack that traps when an arranged view hides, and which it leaves alone.
static void vanish(UIView *view) {
    if (!view) return;
    if (view.alpha != 0) view.alpha = 0;
    if (view.userInteractionEnabled) view.userInteractionEnabled = NO;
    view.accessibilityElementsHidden = YES;
}

// The outermost view that still wraps the control exactly: the element view Spotify's layout places, so
// concealing it leaves the control itself alone to be read and fired.
static UIView *wrapperFor(UIView *control, UIView *stop) {
    UIView *wrapper = control;
    for (UIView *v = control.superview; v && v != stop; v = v.superview) {
        if (fabs(v.bounds.size.width - control.bounds.size.width) > 4) break;
        if (fabs(v.bounds.size.height - control.bounds.size.height) > 4) break;
        wrapper = v;
    }
    return wrapper;
}

// One of the two controls Spotify floats over the page. They are direct children of the page and 48pt
// across, so only the small children are searched: the wash, the tab and the navigation bar are the width
// of the page, and walking into the tab would be walking the whole list on every pass that missed.
static UIView *floatingIn(UIView *page, NSString *identifier, const void *cacheKey) {
    for (UIView *sub in page.subviews) {
        if (sub.bounds.size.width > 120) continue;
        UIView *found = SGRFindByIdentifier(sub, identifier, cacheKey);
        if (found) return found;
    }
    return nil;
}

static void setFrame(UIView *view, CGRect frame) {
    if (view && !CGRectIsEmpty(frame) && !CGRectEqualToRect(view.frame, frame)) view.frame = frame;
}

// `view` moved to the middle of its parent's width, keeping its size and its y.
static void centre(UIView *view) {
    if (!view.superview || view.bounds.size.width <= 0) return;
    CGRect frame = view.frame;
    frame.origin.x = round((view.superview.bounds.size.width - frame.size.width) / 2);
    setFrame(view, frame);
}

static void styleLabels(UIView *root, UIColor *color, UIFont *font, NSTextAlignment alignment) {
    SGForEachView(root, ^(UIView *v) {
        if (![v isKindOfClass:UILabel.class]) return;
        UILabel *label = (UILabel *)v;
        if (color && ![label.textColor isEqual:color]) label.textColor = color;
        if (font && ![label.font isEqual:font]) label.font = font;
        if (label.textAlignment != alignment) label.textAlignment = alignment;
    });
}

// Installs `laidOut` on the view's own pass once, under `key`.
static void watch(UIView *view, const void *key, void (^laidOut)(UIView *view)) {
    if (!view || objc_getAssociatedObject(view, key)) return;
    objc_setAssociatedObject(view, key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SGRObserveLayout(view, laidOut);
}

#pragma mark - the cover, full bleed

// The picture across the top of the page with the field showing through the bottom of it. Two gradients
// rather than a mask or a blur: a scrim over the top for the status bar, and under it a fade from the
// picture to the very colour the page's field is drawing, so the two meet with nothing to see.
@interface SGRAlbumHero : UIView
@property (nonatomic, readonly) UIImageView *picture;
@property (nonatomic, copy) UIColor *fieldColor;
@end

@implementation SGRAlbumHero {
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
    if (self.superview) self.fieldColor = SGRAlbumFieldColor(self);
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

static void showCover(SGRAlbumHero *hero, UIImageView *view, UIView *header) {
    UIImage *image = view.image;
    if (!image || view.bounds.size.width < kMinCover) return;
    if (hero.picture.image != image) hero.picture.image = image;
    SGRAlbumSetArtwork(header, image);
}

// The picture runs from the top of the header down to where its text begins, in the header's own space:
// below that the page's field is already drawing the very colour the picture dissolves into, so the hero
// simply stops there and there is no seam to see.
//
// The furthest down the text has been, rather than where it is: a header still loading puts its title
// higher than it will end up, and a header whose cover has not arrived puts it higher still. Both are
// answered by only ever letting the height grow, which settles once the cover and the artist are in.
static void applyHero(UIView *header, UIView *cover, UIView *titleBlock) {
    SGRAlbumHero *hero = objc_getAssociatedObject(header, &kHeroKey);
    if (!hero) {
        hero = [[SGRAlbumHero alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(header, &kHeroKey, hero, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (hero.superview != header) [header insertSubview:hero atIndex:0];
    else if (header.subviews.firstObject != hero) [header sendSubviewToBack:hero];

    CGFloat height = [objc_getAssociatedObject(hero, &kHeroHeightKey) doubleValue];
    CGFloat top = [header convertPoint:CGPointZero fromView:titleBlock].y;
    if (top > height + 0.5) {
        height = top;
        objc_setAssociatedObject(hero, &kHeroHeightKey, @(height), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SGLog(@"redesign album: hero %.0fpt across the top of the header", height);
    }
    if (height < kMinHero) return;
    setFrame(hero, CGRectMake(0, 0, header.bounds.size.width, height));
    hero.fieldColor = SGRAlbumFieldColor(header);

    UIImageView *source = coverImageIn(cover);
    showCover(hero, source, header);
    // The cover loads after the header is laid out, and a new image lays nothing out again.
    if (source && !objc_getAssociatedObject(source, &kCoverWatchedKey)) {
        objc_setAssociatedObject(source, &kCoverWatchedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak SGRAlbumHero *weakHero = hero;
        __weak UIView *weakHeader = header;
        SGRObserveImage(source, ^(UIImageView *view) {
            if (weakHero && weakHeader) showCover(weakHero, view, weakHeader);
        });
    }
    conceal(cover);
}

#pragma mark - the title, the artist and the date

// The title block's stack hugs the widest thing in it and sits 16pt from the leading edge; centred in a
// block widened to the page, it is the column the Music app draws.
//
// The type is Spotify's own, colour and alignment apart. Unlike the playlist's, this header is measured
// from what it holds: the title's width is a constraint the element framework worked out for the font it
// was shown in, and a font of the Kit's a point larger is a title cut off at the end of it.
static void applyTitleStack(UIView *stack, UIView *title, UIView *parent) {
    styleLabels(title, SGRPrimary(), nil, NSTextAlignmentCenter);
    styleLabels(parent, SGRAccent(), nil, NSTextAlignmentCenter);
    for (UIView *row in stack.subviews) {
        if (row.bounds.size.height <= 0 || row.bounds.size.width <= 0) continue;
        centre(row);
    }
}

// The kind and the date ("Album • 31. 1. 2025") are cells of a collection view as wide as the page's text
// column, laid out from its leading edge. It is Spotify's own Swift class, so its pass cannot be watched
// and its cells are not moved: the row is centred by the inset the collection scrolls its content at,
// which no layout pass of Spotify's writes over.
static void applyMetadata(UIView *metadata) {
    __block UICollectionView *cells = nil;
    SGForEachView(metadata, ^(UIView *v) {
        if (!cells && [v isKindOfClass:UICollectionView.class]) cells = (UICollectionView *)v;
    });
    styleLabels(metadata, SGRTertiary(), nil, NSTextAlignmentCenter);
    // Asked of the layout rather than read off the scroll view: a pass runs top down, so every view whose
    // pass this can be watched from has already run by the time the cells lay themselves out, and
    // contentSize is a pass behind on every one of them (0 for as long as the header stands still).
    CGFloat room = cells.bounds.size.width;
    CGFloat content = MAX(cells.contentSize.width, cells.collectionViewLayout.collectionViewContentSize.width);
    if (room <= 0 || content <= 0 || content >= room) return;
    CGFloat lead = round((room - content) / 2);
    if (fabs(cells.contentInset.left - lead) > 0.5) cells.contentInset = UIEdgeInsetsMake(0, lead, 0, 0);
}

#pragma mark - the action row

// Shuffle, Play and add, centred, with more beside them when Spotify has not moved it into the navigation
// bar. Glass goes inside each of Spotify's round buttons (the Kit's way: the shape is the button's own
// subview, so it goes wherever the button is put); the capsule and the stand-in carry their own.
static void applyActions(UIView *row, UIView *header, UIView *page) {
    UIView *add = SGRFindByIdentifier(row, @"Components.UI.AddToButton", &kAddKey);
    UIView *more = SGRFindByIdentifier(row, @"Components.UI.ContextMenuButton*", &kMoreKey);
    // The Music app has neither on an album: a video entry point, and a download button the mod's own
    // downloads do not need beside it.
    for (NSString *identifier in @[@"Components.UI.WatchFeedEntityExplorerButton", @"DownloadButton.Granular*",
                                   @"Components.UI.ShareButton"]) {
        UIView *gone = SGRFindByIdentifier(row, identifier, NULL);
        if (gone) vanish(wrapperFor(gone, row));
    }

    UIView *play = floatingIn(page, @"header-play-button", &kPlayKey);
    UIView *shuffle = floatingIn(page, @"Components.UI.ShuffleButton", &kShuffleKey);

    SGRPlayCapsule *capsule = objc_getAssociatedObject(row, &kCapsuleKey);
    if (!capsule) {
        capsule = [[SGRPlayCapsule alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(row, &kCapsuleKey, capsule, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (capsule.superview != row) [row addSubview:capsule];
    if (play) {
        [capsule feedFrom:play];
        // Only what the button draws goes: a concealed layer still sends the actions the capsule fires.
        conceal(wrapperFor(play, page));
    }
    capsule.hidden = play == nil;

    SGRMirrorButton *mirror = objc_getAssociatedObject(row, &kMirrorKey);
    if (!mirror) {
        mirror = [[SGRMirrorButton alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(row, &kMirrorKey, mirror, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (mirror.superview != row) [row addSubview:mirror];
    if (shuffle) {
        [mirror feedFrom:shuffle];
        conceal(wrapperFor(shuffle, page));
    }
    mirror.hidden = shuffle == nil;

    NSMutableArray<UIView *> *items = [NSMutableArray array];
    NSMutableArray<NSNumber *> *widths = [NSMutableArray array];
    if (shuffle) { [items addObject:mirror]; [widths addObject:@(SGRActionHeight)]; }
    if (play) { [items addObject:capsule]; [widths addObject:@([capsule sgr_width])]; }
    if (add) { [items addObject:wrapperFor(add, row)]; [widths addObject:@(SGRActionHeight)]; }
    if (more) { [items addObject:wrapperFor(more, row)]; [widths addObject:@(SGRActionHeight)]; }
    if (!items.count) return;

    CGFloat total = (items.count - 1) * SGRActionSpacing;
    for (NSNumber *width in widths) total += width.doubleValue;
    CGFloat x = round((row.bounds.size.width - total) / 2), middle = CGRectGetMidY(row.bounds);
    for (NSUInteger i = 0; i < items.count; i++) {
        UIView *item = items[i];
        CGFloat slot = widths[i].doubleValue;
        BOOL ours = item == (UIView *)capsule || item == (UIView *)mirror;
        CGSize size = ours ? CGSizeMake(slot, SGRActionHeight) : item.bounds.size;
        setFrame(item, CGRectMake(round(x + (slot - size.width) / 2), round(middle - size.height / 2), size.width, size.height));
        x += slot + SGRActionSpacing;
    }
    for (UIView *button in @[add ?: NSNull.null, more ?: NSNull.null]) {
        if ([button isKindOfClass:UIView.class]) SGRGlassInside(button, &kGlassKey, SGRGlassCircleSize);
    }

    static BOOL logged;
    if (!logged && row.window) {
        logged = YES;
        SGLog(@"redesign album: action row %@, shuffle %@, play %@, add %@, more %@", NSStringFromCGRect(row.bounds),
              shuffle ? @"found" : @"missing", play ? @"found" : @"missing", add ? @"found" : @"missing",
              more ? @"in the row" : @"not in the page");
    }
}

#pragma mark - the header's pass

// Drawn by nothing, whatever Spotify does to it: an empty mask. Spotify switches the navigation bar's
// gradient on and off with -setHidden:, which writes the layer's own hidden and so undoes conceal(); and
// it fades both gradients by alpha. Neither touches a mask.
static void maskOut(UIView *view) {
    if (!view || view.layer.mask) return;
    view.layer.mask = [CALayer layer];
    view.accessibilityElementsHidden = YES;
}

// The colour Spotify painted the wash in: the first opaque colour of the gradient layer it draws with,
// whether that is the view's own layer or one under it. nil when it draws some other way, or has
// no colour yet.
static UIColor *washColorOf(UIView *gradient) {
    NSMutableArray<CALayer *> *layers = [NSMutableArray arrayWithObject:gradient.layer];
    [layers addObjectsFromArray:gradient.layer.sublayers ?: @[]];
    for (CALayer *layer in layers) {
        if (![layer isKindOfClass:CAGradientLayer.class]) continue;
        for (id value in ((CAGradientLayer *)layer).colors) {
            CGColorRef cg = (__bridge CGColorRef)value;
            if (CFGetTypeID(cg) != CGColorGetTypeID() || CGColorGetAlpha(cg) < 0.5) continue;
            // The page's base surface is what a wash is before Spotify has a colour for it, not a colour.
            if (SGIsBaseSurface(cg)) return nil;
            return [UIColor colorWithCGColor:cg];
        }
    }
    return nil;
}

// Spotify's colour wash behind the header goes, so the page's field shows through, and the colour it was
// painted in goes to the field: Spotify reads the whole cover for it, where the Kit reads the bottom edge.
//
// The navigation bar's gradient goes too. Hidden at rest, it is shown as the page scrolls under the
// title, and over the field it was a flat dark band across the top (device, 2026-09-18). What keeps the
// title legible over the list is the soft top edge every redesigned page has (SGREdgeEffect.x), as it is
// on Home, Search and Library.
static void applyWash(UIView *page) {
    for (UIView *sub in page.subviews) {
        NSString *name = NSStringFromClass(sub.class);
        if (![name containsString:@"HeaderView"] && ![name containsString:@"HeaderNavigationBar"]) continue;
        BOOL wash = ![name containsString:@"NavigationBar"];
        for (UIView *v in sub.subviews) {
            if (![NSStringFromClass(v.class) containsString:@"GradientView"]) continue;
            if (wash) {
                UIColor *color = washColorOf(v);
                static BOOL logged;
                if (!logged) {
                    logged = YES;
                    SGLog(@"redesign album: Spotify's wash %@ on %@, colour %@", NSStringFromClass(v.class),
                          NSStringFromClass(v.layer.class), color ?: @"not found");
                }
                SGRAlbumSetSpotifyColor(page, color);
            }
            maskOut(v);
        }
    }
}

// The stack view `view` is arranged by, or nil: what has to lay out before `view` can be moved. Asked
// through -class, which a watch's runtime subclass answers with the class Spotify made.
static UIStackView *stackOver(UIView *view) {
    UIStackView *stack = (UIStackView *)view.superview;
    return [stack class] == UIStackView.class ? stack : nil;
}

static void applyHeader(UIView *header, UIView *page) {
    UIView *title = SGRFindByIdentifier(header, @"CreativeWorkPlatform.Components.UI.TitleRow", &kTitleKey);
    UIView *parent = SGRFindByIdentifier(header, @"CreativeWorkPlatform.Components.UI.ParentRow", &kParentKey);
    UIView *titleStack = title.superview;
    UIView *titleBlock = titleStack.superview;
    if (!titleBlock) return;

    applyWash(page);
    UIView *cover = SGRFindByIdentifier(header, @"CreativeWorkPlatform.Components.UI.ArtWorkElement.WithCoverArt", &kCoverKey);
    if (cover) applyHero(header, cover, titleBlock);

    // The title block hugs its text, so it is widened to the group it is arranged in before the stack
    // inside it is centred; the group lays the block out, so that is the pass it is taken from.
    UIStackView *group = stackOver(titleBlock);
    void (^widenBlock)(UIView *) = ^(UIView *view) {
        CGRect frame = titleBlock.frame;
        setFrame(titleBlock, CGRectMake(0, frame.origin.y, view.bounds.size.width, frame.size.height));
    };
    if (group) {
        widenBlock(group);
        watch(group, &kGroupWatchedKey, widenBlock);
    }
    centre(titleStack);
    watch(titleBlock, &kBlockWatchedKey, ^(UIView *view) { centre(titleStack); });
    applyTitleStack(titleStack, title, parent);
    watch(titleStack, &kTitleWatchedKey, ^(UIView *view) { applyTitleStack(view, title, parent); });

    UIView *metadata = SGRFindByIdentifier(header, @"Components.UI.MetadataRow", &kMetaKey);
    UIStackView *metaStack = stackOver(metadata.superview) ?: stackOver(metadata);
    if (metadata) {
        applyMetadata(metadata);
        watch(metaStack ?: metadata, &kMetaWatchedKey, ^(UIView *view) { applyMetadata(metadata); });
    }

    // The action row is whichever stack Spotify's own buttons are arranged in, found from the first of them
    // that is still in the page, and widened to its group the way the title block is.
    UIView *anyButton = SGRFindByIdentifier(header, @"Components.UI.AddToButton", &kAddKey)
                     ?: SGRFindByIdentifier(header, @"DownloadButton.Granular*", NULL)
                     ?: SGRFindByIdentifier(header, @"Components.UI.ContextMenuButton*", &kMoreKey);
    UIStackView *actions = (UIStackView *)wrapperFor(anyButton, header).superview;
    if (![actions isKindOfClass:UIStackView.class]) return;
    UIStackView *bottom = stackOver(actions);
    void (^widenRow)(UIView *) = ^(UIView *view) {
        CGRect frame = actions.frame;
        setFrame(actions, CGRectMake(0, frame.origin.y, view.bounds.size.width, frame.size.height));
    };
    if (bottom) {
        widenRow(bottom);
        watch(bottom, &kBottomWatchedKey, widenRow);
    }
    applyActions(actions, header, page);
    // Weakly: the row is the page's own descendant, and a block of its that held the page would keep the
    // whole page alive for as long as the row.
    __weak UIView *weakHeader = header, *weakPage = page;
    watch(actions, &kActionsWatchedKey, ^(UIView *view) {
        if (weakHeader && weakPage) applyActions(view, weakHeader, weakPage);
    });
}

static void applyPage(UIView *page) {
    UIView *header = SGRFindByIdentifier(page, @"CreativeWorkPlatform.Components.UI.CreativeWorkHeader", &kHeaderKey);
    if (!header) return;
    applyHeader(header, page);
    // The header lays itself out again whenever its cover, its artist or its buttons arrive, which the
    // page's own pass does not hear about. It is a plain UIView, so its pass can be watched.
    watch(header, &kHeaderWatchedKey, ^(UIView *view) {
        UIView *owner = SGRAlbumPageOf(view);
        if (owner) applyHeader(view, owner);
    });
}

%hook _TtC28CreativeWorkPlatform_PageKit24CreativeWorkTemplateView
- (void)layoutSubviews {
    %orig;
    applyPage((UIView *)self);
}
%end

// The play button arrives in the page after the row that replaces it has been laid out, so a page opening
// showed Spotify's green disc in the corner until something else laid the page out. Its own pass is where
// it goes, and the class is Spotify's own so nothing else pays for the check.
%hook _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView
- (void)layoutSubviews {
    %orig;
    UIView *button = (UIView *)self;
    if (button.layer.hidden || ![button.accessibilityIdentifier isEqualToString:@"header-play-button"]) return;
    UIView *page = SGRAlbumPageOf(button);
    if (!page) return;
    conceal(wrapperFor(button, page));
    applyPage(page);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[
        @"_TtC28CreativeWorkPlatform_PageKit24CreativeWorkTemplateView",
        @"_TtC28EncoreConsumerMobile_BaseKit14PlayButtonView",
    ]);
}
