// Playlist redesign: the header the Music app gives a playlist. The cover runs full bleed across the top of
// the page and dissolves into the field under it, with no seam and no card; the title, the creator and the
// length are centred under it; and one row of glass controls sits below them -- shuffle, a prominent Play
// capsule, add, and more where Spotify still keeps it in the page.
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
// height and moves nothing between the two: the cover's square is where the full bleed picture goes, and
// the block keeps its place with its own contents rearranged. The header then collapses, snaps and scrolls
// exactly as Spotify laid it out.
//
// Whose layout pass. A view lays its children out, so a frame set from an ancestor's layoutSubviews is the
// one that is overwritten a moment later -- the column and the action row are both laid out by Spotify
// after HeaderContentLayout's pass has returned. Both of them are plain UIViews, so each is watched for its
// own pass with the Kit's SGRObserveLayout, and the header's pass only finds them and starts the watch.
//
// Every one of Spotify's controls stays Spotify's own, with its action, its state and its accessibility:
// they are moved by frame, never rebuilt. The one exception is Play, which the Music app draws as a capsule
// with a word in it rather than a disc: the capsule is the Kit's, it takes the glyph and the word from
// Spotify's own button (so play, pause and the language are Spotify's), and a tap on it fires that button.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Playlist.h"

// How much of the cover's height the dissolve into the field covers, and the scrim over the top of it that
// keeps the status bar and the back button legible on a bright picture.
static const CGFloat kDissolve = 0.46, kTopScrim = 140, kTopScrimAlpha = 0.28;
// A header whose cover square is smaller than this is one mid collapse or mid load, not one to measure
// the hero from; and an artwork view narrower than this is a placeholder glyph rather than the cover.
static const CGFloat kMinHero = 120, kMinCover = 80;

static char kCoverKey, kRowKey, kMetaKey, kPlayKey, kGlassKey, kLayoutKey;
static char kShuffleKey, kAddKey, kMoreKey, kToolbarKey;
static char kHeroKey, kHeroHeightKey, kCapsuleKey, kColumnWatchedKey, kRowWatchedKey, kCoverWatchedKey;

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

// Invisible for good. Spotify fades its cover square and its colour wash back in from the scroll itself,
// with nothing laid out (trees/continuous/1.txt, 2026-09-17), so a redesign that answers with alpha is in a
// fight it loses a frame of on every scroll -- which is what the flicker was. `hidden` on the layer cannot
// be undone by a write to alpha, costs nothing per frame, and, unlike -[UIView setHidden:], tells neither
// KVO nor the stack views of it, which is what makes it safe on Spotify's Encore layouts.
static void conceal(UIView *view) {
    if (!view) return;
    if (!view.layer.hidden) view.layer.hidden = YES;
    if (view.userInteractionEnabled) view.userInteractionEnabled = NO;
    view.accessibilityElementsHidden = YES;
}

// Alpha 0, no touches, hidden from accessibility, set again on every pass: for the buttons of the action row,
// which Spotify arranges in stacks that trap when an arranged view is hidden, and which it leaves alone.
static void vanish(UIView *view) {
    if (!view) return;
    if (view.alpha != 0) view.alpha = 0;
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

// The outermost view that still wraps the button exactly: what Spotify's stack arranges, and so what moves
// without the button coming loose from whatever draws around it.
static UIView *wrapperFor(UIView *button, UIView *stop) {
    UIView *wrapper = button;
    for (UIView *v = button.superview; v && v != stop; v = v.superview) {
        if (fabs(v.bounds.size.width - button.bounds.size.width) > 4) break;
        if (fabs(v.bounds.size.height - button.bounds.size.height) > 4) break;
        wrapper = v;
    }
    return wrapper;
}

// A rect of `container`'s, set on a view that hangs somewhere else in the header. Nothing on the way down to
// the action row clips, so a control placed from its own parent lands where the row wants it.
static void place(UIView *view, CGRect target, UIView *container) {
    if (!view.superview || CGRectIsEmpty(target)) return;
    CGRect local = [view.superview convertRect:target fromView:container];
    if (!CGRectEqualToRect(view.frame, local)) view.frame = local;
}

static void styleLabels(UIView *root, UIColor *color, UIFont *font, NSTextAlignment alignment) {
    SGForEachView(root, ^(UIView *v) {
        if ([v isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)v;
            if (color && ![label.textColor isEqual:color]) label.textColor = color;
            if (font && ![label.font isEqual:font]) label.font = font;
            if (label.textAlignment != alignment) label.textAlignment = alignment;
        } else if ([v isKindOfClass:UITextView.class]) {
            UITextView *text = (UITextView *)v;
            if (color && ![text.textColor isEqual:color]) text.textColor = color;
            if (text.textAlignment != alignment) text.textAlignment = alignment;
        }
    });
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
// Its height is where the header's text begins, taken in the plane's own space. Below that the page's field
// is already drawing the very colour the picture dissolves into, so the hero simply stops there: pulled down
// past the top, where Spotify moves its text down and leaves a gap, that gap is the same colour and there is
// no seam to see.
static void applyHero(UIView *layout, UIView *cover, UIView *plane, UIView *block) {
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
    CGRect frame = CGRectMake(0, 0, plane.bounds.size.width, height);
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

#pragma mark - the column

// Title, creator and length centred under the cover, the description last, the way the Music app reads. The
// four sit as frames in a plain UIView, so the order is the order they are given, and the column keeps the
// height Spotify measured for it: what is laid out here never grows past it.
static void applyColumn(UIView *column) {
    UIView *title = nil, *description = nil, *creator = nil, *length = nil;
    for (UIView *row in column.subviews) {
        if (SGHasClass(row, @"ExpandableTextView")) description = row;
        else if (SGHasClass(row, @"FacepileView")) creator = row;
        else if (SGRFindByIdentifier(row, @"Components.Header.UI.Metadata", &kMetaKey)) length = row;
        else if (!title) title = row;
    }
    if (!title) return;

    styleLabels(title, SGRPrimary(), SGRFont(UIFontTextStyleTitle2, UIFontWeightSemibold, UIContentSizeCategoryLarge), NSTextAlignmentCenter);
    styleLabels(creator, SGRAccent(), nil, NSTextAlignmentCenter);
    styleLabels(length, SGRTertiary(), nil, NSTextAlignmentCenter);
    styleLabels(description, SGRSecondary(), nil, NSTextAlignmentCenter);

    NSMutableArray<UIView *> *rows = [NSMutableArray array];
    NSMutableArray<NSNumber *> *gaps = [NSMutableArray array];
    NSArray *order = @[title, creator ?: NSNull.null, length ?: NSNull.null, description ?: NSNull.null];
    NSArray<NSNumber *> *after = @[@6, @2, @8, @0];
    for (NSUInteger i = 0; i < order.count; i++) {
        UIView *row = (UIView *)order[i];
        if (![row isKindOfClass:UIView.class] || row.hidden || row.bounds.size.height <= 0) continue;
        [rows addObject:row];
        [gaps addObject:after[i]];
    }

    CGFloat width = column.bounds.size.width, room = column.bounds.size.height;
    CGFloat bare = 0;
    for (UIView *row in rows) bare += row.bounds.size.height;
    CGFloat spacing = 0;
    for (NSUInteger i = 0; i + 1 < rows.count; i++) spacing += gaps[i].doubleValue;
    // Spotify measured the column for the same four, so this is room enough; a description that has grown
    // since gives the gaps up first and then goes, rather than reaching down into the action row.
    BOOL spaced = bare + spacing <= room;
    if (bare > room && description && [rows containsObject:description]) {
        [rows removeObject:description];
        vanish(description);
    }

    CGFloat y = 0;
    for (NSUInteger i = 0; i < rows.count; i++) {
        UIView *row = rows[i];
        CGSize size = row.bounds.size;
        // A row Spotify fills the width with centres its own text; one that holds a narrow stack of its own
        // is moved instead, keeping its width so the stack inside it is not laid out differently.
        CGFloat content = size.width;
        for (UIView *part in row.subviews) {
            if (part.bounds.size.width > 0 && part.bounds.size.width < content) content = part.bounds.size.width;
        }
        CGFloat x = content < size.width - 1 ? round((width - content) / 2) : 0;
        CGRect frame = CGRectMake(x, round(y), size.width, size.height);
        if (!CGRectEqualToRect(row.frame, frame)) row.frame = frame;
        y += size.height + (spaced && i + 1 < rows.count ? gaps[i].doubleValue : 0);
    }
}

#pragma mark - the action row

// Shuffle, Play and add, centred, with more beside them when Spotify has not moved it into the navigation
// bar. Glass goes inside each of Spotify's round buttons (the Kit's way: the shape is the button's own
// subview, so it goes wherever the button is put); the capsule carries its own.
static void applyActions(UIView *block, UIView *headerRoot) {
    UIView *row = SGRFindByIdentifier(block, @"HeaderActionsRow", &kRowKey);
    // The row of the block, not the box Spotify wraps its own half of it in: a plain UIView as wide as the
    // block itself, which is the one the centred row is measured against (the harness placed the group 90pt
    // off centre when the narrower wrapper was taken for it, 2026-09-17).
    UIView *container = nil;
    for (UIView *v = row.superview; v && v != block; v = v.superview) {
        if (object_getClass(v) != UIView.class || v.bounds.size.height > 80) continue;
        if (v.bounds.size.width < block.bounds.size.width - 24) continue;
        container = v;
        break;
    }
    if (!container) return;

    UIView *shuffle = SGRFindByIdentifier(block, @"Components.UI.ShuffleButton", &kShuffleKey);
    UIView *add = SGRFindByIdentifier(block, @"Components.UI.AddToButton", &kAddKey);
    UIView *more = SGRFindByIdentifier(block, @"Components.UI.ContextMenuButton", &kMoreKey);
    for (NSString *identifier in @[@"Components.UI.WatchFeedEntityExplorerButton", @"DownloadButton.Granular*",
                                   @"Components.UI.ShareButton", @"MixAndShuffleComposedUI.mixView"]) {
        UIView *gone = SGRFindByIdentifier(block, identifier, NULL);
        if (gone) vanish(wrapperFor(gone, container));
    }

    SGRPlayCapsule *capsule = objc_getAssociatedObject(container, &kCapsuleKey);
    if (!capsule) {
        capsule = [[SGRPlayCapsule alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(container, &kCapsuleKey, capsule, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (capsule.superview != container) [container addSubview:capsule];
    UIView *playButton = SGRFindByIdentifier(headerRoot, @"header-play-button", &kPlayKey);
    if (playButton) {
        [capsule feedFrom:playButton];
        // Only what the button draws goes: a concealed layer still sends the actions the capsule fires.
        conceal(playButton);
    }
    capsule.hidden = playButton == nil;

    NSMutableArray<UIView *> *items = [NSMutableArray array];
    NSMutableArray<NSNumber *> *widths = [NSMutableArray array];
    if (shuffle) { [items addObject:wrapperFor(shuffle, container)]; [widths addObject:@(SGRActionHeight)]; }
    if (playButton) { [items addObject:capsule]; [widths addObject:@([capsule sgr_width])]; }
    if (add) { [items addObject:wrapperFor(add, container)]; [widths addObject:@(SGRActionHeight)]; }
    if (more) { [items addObject:wrapperFor(more, container)]; [widths addObject:@(SGRActionHeight)]; }
    if (!items.count) return;

    CGFloat total = (items.count - 1) * SGRActionSpacing;
    for (NSNumber *width in widths) total += width.doubleValue;
    CGFloat x = round((container.bounds.size.width - total) / 2), middle = CGRectGetMidY(container.bounds);
    for (NSUInteger i = 0; i < items.count; i++) {
        UIView *item = items[i];
        CGFloat slot = widths[i].doubleValue;
        CGSize size = item == capsule ? CGSizeMake(slot, SGRActionHeight) : item.bounds.size;
        CGRect target = CGRectMake(round(x + (slot - size.width) / 2), round(middle - size.height / 2), size.width, size.height);
        if (item == capsule) {
            if (!CGRectEqualToRect(capsule.frame, target)) capsule.frame = target;
        } else {
            place(item, target, container);
        }
        x += slot + SGRActionSpacing;
    }
    for (UIView *button in @[shuffle ?: NSNull.null, add ?: NSNull.null, more ?: NSNull.null]) {
        if ([button isKindOfClass:UIView.class]) SGRGlassInside(button, &kGlassKey, SGRGlassCircleSize);
    }

    static BOOL logged;
    if (!logged && container.window) {
        logged = YES;
        SGLog(@"redesign playlist: action row %@, shuffle %@, play %@, add %@, more %@", NSStringFromCGRect(container.bounds),
              shuffle ? @"found" : @"missing", playButton ? @"found" : @"missing", add ? @"found" : @"missing",
              more ? @"in the row" : @"not in the page");
    }
}

#pragma mark - the header's pass

// Find on this page and Sort sit in a header view of their own above the cover, invisible until the page is
// scrolled; the Music app has neither.
static void applyToolbar(UIView *headerRoot) {
    UIView *toolbar = SGRFindByIdentifier(headerRoot, @"Components.Header.UI.Toolbar.Content", &kToolbarKey);
    for (UIView *v = toolbar; v && v != headerRoot; v = v.superview) {
        if (![NSStringFromClass(v.class) containsString:@"HeaderView"]) continue;
        conceal(v);
        return;
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

// The layout holds the cover square and, under it, the block of text and controls.
static UIView *blockIn(UIView *layout, UIView *cover) {
    UIView *block = nil;
    for (UIView *sub in layout.subviews) {
        if (sub == cover || [sub isKindOfClass:SGRPlaylistHero.class]) continue;
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
    if (cover) applyHero(layout, cover, plane, block);

    // The column and the action row lay their own children out after this pass; each is watched once so the
    // redesign has the last word on both.
    UIView *metadata = SGRFindByIdentifier(block, @"Components.Header.UI.Metadata", &kMetaKey);
    UIView *column = nil;
    for (UIView *v = metadata; v && v != block; v = v.superview) {
        if ([NSStringFromClass(v.superview.class) containsString:@"AutoLayoutStackView"]) { column = v; break; }
    }
    if (column) {
        applyColumn(column);
        if (!objc_getAssociatedObject(column, &kColumnWatchedKey)) {
            objc_setAssociatedObject(column, &kColumnWatchedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            SGRObserveLayout(column, ^(UIView *view) { applyColumn(view); });
        }
    }

    applyActions(block, headerRoot);
    UIView *row = SGRFindByIdentifier(block, @"HeaderActionsRow", &kRowKey);
    if (row && !objc_getAssociatedObject(row, &kRowWatchedKey)) {
        objc_setAssociatedObject(row, &kRowWatchedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        __weak UIView *weakBlock = block, *weakRoot = headerRoot;
        SGRObserveLayout(row, ^(UIView *view) {
            if (weakBlock && weakRoot) applyActions(weakBlock, weakRoot);
        });
    }
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
