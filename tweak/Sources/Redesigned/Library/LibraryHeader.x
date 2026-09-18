// Library redesign: the header of Your Library and of a folder inside it, the way Home and Search have theirs
// (Redesigned/Home/HomeHeader.x, Redesigned/Search/SearchPage.x). A large title at the leading edge, the avatar
// that opens the side drawer at the trailing edge, the filter chips gone, and the scrim Spotify lays behind the
// header gone with them, the soft scroll edge (Kit/SGREdgeEffect.x) being what keeps the header clear of the
// list scrolling under it.
//
// Tree (trees/clean/library/03.txt:1159-1247): YourLibraryView holds YourLibraryContentView, the size of the
// page, and after it -- so over it -- YourLibraryHeaderView 402x159.33: LiquidGlass.GradientView (the scrim), a
// 402x48 row at {0, 62} holding an AutoLayoutStackView {8, 0} 390x48 of
// ListeningActivity_ElementsKit.AdaptiveFaceContainer (the avatar, id=Components.UI.SideDrawerButton),
// id=YourLibraryHeader.title ("Your Library", 21pt), a spacer, a hidden id=YourLibraryHeader.recents,
// id=YourLibraryHeader.search and id=YourLibraryHeader.plus; and under the row
// YourLibraryHeaderContentFiltersView {0, 110} 402x49.33, the chips. A folder (trees/continuous/1.txt:325-344)
// is the same header under YourLibrary_FolderImpl, with id=YourLibraryFolderHeader.back at the leading edge,
// its title, then contextMenu, plus and play or pause, and the chips at {0, 118}.
//
// The header neither moves nor shrinks as the list scrolls -- 03.txt, 05.txt and 06.txt hold it at
// {0, 0} 402x159.33 at three scroll positions -- so there is nothing here to follow: the row is laid out once a
// pass and stays where it is put.
//
// Each control moves by a transform rather than by a frame. Spotify's stack lays them out from constraints of
// its own on every pass, and Auto Layout sets a view's centre and bounds and leaves its transform alone, so the
// move outlives the pass that made it (Search moves the Browse cells the same way). Nothing leaves the stack:
// an arranged view of Spotify's that hides traps its stack in updateConstraints (Kit/SGRRestyle.h), so what
// goes is alpha, touches and accessibility, and the title Spotify draws goes that way while ours is a subview
// of the header the stack does not arrange.
//
// The chips leaving takes 49pt off the bottom of the header. What the header is shrunk to is the bottom of its
// control row, which hangs off the safe area rather than off the header and so answers the same on every pass,
// shrunk header or not; the chips' own top would move with the header and shrink it again pass after pass. The
// page under it is then closed up the way that page holds its list: the root insets the list's top by the
// header's height, a folder puts its content view below the header instead.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Library.h"

NSString *const SGRLibraryListIdentifier = @"YourLibraryContent.collectionView";

// Spotify's own inset for the header's controls: a 48pt button flush against the header's trailing edge has its
// 24pt glyph 20pt from the screen, and the 32pt avatar inside its own 48pt box 16pt from it, which is the
// margin Home gives the avatar.
static const CGFloat kRowInset = 8;
// A header shorter than this has not been laid out yet, and nothing is resized from it.
static const CGFloat kHeaderFloor = 88;

static char kTitleKey, kListKey, kInsetKey;
static char kSearchKey, kPlusKey, kHeaderTitleKey;
static char kBackKey, kMenuKey, kFolderPlusKey, kPlayKey, kPauseKey, kFolderTitleKey;

static void vanish(UIView *view) {
    if (!view) return;
    if (view.alpha != 0) view.alpha = 0;
    if (view.userInteractionEnabled) view.userInteractionEnabled = NO;
    view.accessibilityElementsHidden = YES;
}

static UIView *childNamed(UIView *host, NSString *marker) {
    for (UIView *sub in host.subviews) {
        if ([NSStringFromClass(sub.class) containsString:marker]) return sub;
    }
    return nil;
}

void SGRLibraryClearScrim(UIView *header) {
    vanish(childNamed(header, @"GradientView"));
}

#pragma mark - the controls

// The header's controls, in the order they are to read from the leading edge, leaving out what this build does
// not have, what Spotify has hidden (a folder shows play or pause, never both) and what has not been laid out.
static NSMutableArray<UIView *> *controlsIn(UIView *header, NSArray<NSString *> *identifiers, const void **keys) {
    NSMutableArray<UIView *> *found = [NSMutableArray array];
    for (NSUInteger i = 0; i < identifiers.count; i++) {
        UIView *control = SGRFindByIdentifier(header, identifiers[i], keys[i]);
        if (control && !control.hidden && control.alpha > 0.01 && control.bounds.size.width > 1) [found addObject:control];
    }
    return found;
}

// Puts the controls at the header's trailing edge, the last of them flush against it and each keeping the width
// it has, and answers where the leading edge of the first of them fell.
static CGFloat placeTrailing(UIView *header, NSArray<UIView *> *controls) {
    CGFloat right = header.bounds.size.width - kRowInset;
    for (UIView *control in controls.reverseObjectEnumerator) {
        CGFloat width = control.bounds.size.width;
        // The centre is where Auto Layout put the control, whatever transform is on it; its frame is not.
        CGFloat natural = [control.superview convertPoint:CGPointZero toView:header].x + control.center.x - width / 2;
        CGAffineTransform move = CGAffineTransformMakeTranslation(right - width - natural, 0);
        if (!CGAffineTransformEqualToTransform(control.transform, move)) control.transform = move;
        right -= width;
    }
    return right;
}

#pragma mark - the title

static NSString *textIn(UIView *label) {
    __block NSString *text = nil;
    SGForEachView(label, ^(UIView *view) {
        if (!text && [view isKindOfClass:UILabel.class] && ((UILabel *)view).text.length) text = ((UILabel *)view).text;
    });
    return text;
}

static UILabel *titleIn(UIView *header) {
    UILabel *title = objc_getAssociatedObject(header, &kTitleKey);
    if (!title) {
        title = [UILabel new];
        title.textColor = SGRPrimary();
        title.accessibilityTraits = UIAccessibilityTraitHeader;
        title.adjustsFontSizeToFitWidth = YES;
        title.minimumScaleFactor = 0.6;
        title.userInteractionEnabled = NO;
        objc_setAssociatedObject(header, &kTitleKey, title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (title.superview != header) [header addSubview:title];
    return title;
}

// The title Spotify's own says, so it follows the app's language, in the Music app's size on the row's middle.
static void layoutTitle(UIView *header, UIView *spotifyTitle, CGFloat leading, CGFloat trailing, CGFloat middle) {
    UILabel *title = titleIn(header);
    NSString *text = textIn(spotifyTitle);
    if (text.length && ![title.text isEqualToString:text]) {
        title.text = text;
        title.accessibilityLabel = text;
    }
    UIFont *font = SGRFont(UIFontTextStyleLargeTitle, UIFontWeightBold, UIContentSizeCategoryLarge);
    if (![title.font isEqual:font]) title.font = font;

    CGFloat height = ceil(font.lineHeight);
    CGRect frame = CGRectMake(leading, round(middle - height / 2), MAX(0, trailing - SGRGrid - leading), height);
    if (!CGRectEqualToRect(title.frame, frame)) title.frame = frame;
}

#pragma mark - the page closing up

// The header without its chips, and the page under it closed up by what they leave. `control` is any of the
// header's 48pt controls: they fill its control row, so the bottom of one is the bottom of the row.
static void resize(UIView *page, UIView *header, UIView *control, UIView *filters) {
    if (!filters || !control) return;
    CGFloat wanted = CGRectGetMaxY(SGFrameIn(control, header));
    if (wanted < kHeaderFloor || wanted > header.bounds.size.height + 0.5) return;

    CGRect frame = header.frame;
    if (fabs(frame.size.height - wanted) > 0.5) {
        frame.size.height = wanted;
        header.frame = frame;
    }

    UIView *content = childNamed(page, @"YourLibraryContentView");
    if (!content) return;
    if (CGRectGetMinY(content.frame) > 0.5) {
        // A folder: its content view starts under the header rather than behind it.
        CGRect wantedFrame = CGRectMake(0, wanted, page.bounds.size.width, page.bounds.size.height - wanted);
        if (!CGRectEqualToRect(content.frame, wantedFrame)) content.frame = wantedFrame;
        return;
    }

    // The root: the list rests under the header by an inset of its own. The inset is lowered by the band the
    // chips had rather than set to the header's height, since what Spotify counts into it is its own business,
    // and it is taken once -- after this pass the header no longer says how tall it was -- and then held by the
    // setter hook below, so Spotify setting it again from its own pass is not something to answer pass after
    // pass.
    UIView *found = SGRFindByIdentifier(content, SGRLibraryListIdentifier, &kListKey);
    if (![found isKindOfClass:UIScrollView.class]) return;
    UIScrollView *list = (UIScrollView *)found;
    if (objc_getAssociatedObject(list, &kInsetKey)) return;
    CGFloat drop = CGRectGetMaxY(SGFrameIn(filters, header)) - wanted;
    CGFloat top = list.contentInset.top;
    // Nothing is taken off an inset that does not hold a header yet: the next pass has one.
    if (drop < 1 || top < kHeaderFloor || top < drop) return;
    objc_setAssociatedObject(list, &kInsetKey, @(top - drop), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    BOOL atTop = list.contentOffset.y <= -top + 0.5;
    UIEdgeInsets inset = list.contentInset;
    inset.top = top - drop;
    list.contentInset = inset;
    // A list resting at its top rests that much higher; one scrolled into its rows does not move at all.
    if (atTop) list.contentOffset = CGPointMake(list.contentOffset.x, -inset.top);
    SGLog(@"redesign library: the chips took %.0fpt off the header, the list rests at %.0f", drop, inset.top);
}

#pragma mark - the two headers

static void layoutRoot(UIView *page) {
    UIView *header = childNamed(page, @"YourLibraryHeaderView");
    if (!header) return;
    [header layoutIfNeeded];
    SGRLibraryClearScrim(header);
    UIView *filters = childNamed(header, @"YourLibraryHeaderContentFiltersView");
    vanish(filters);

    UIView *spotifyTitle = SGRFindByIdentifier(header, @"YourLibraryHeader.title", &kHeaderTitleKey);
    vanish(spotifyTitle);
    static const void *keys[] = {&kSearchKey, &kPlusKey};
    NSMutableArray<UIView *> *trailing = controlsIn(header, @[@"YourLibraryHeader.search", @"YourLibraryHeader.plus"], keys);
    static Class faceClass;
    if (!faceClass) faceClass = NSClassFromString(@"_TtC29ListeningActivity_ElementsKit21AdaptiveFaceContainer");
    __block UIView *face = nil;
    SGForEachView(header, ^(UIView *view) {
        if (!face && faceClass && [view isKindOfClass:faceClass] && view.bounds.size.width > 1) face = view;
    });
    if (face) [trailing addObject:face];
    if (!trailing.count) return;

    CGFloat leading = placeTrailing(header, trailing);
    CGRect row = SGFrameIn(trailing.firstObject, header);
    layoutTitle(header, spotifyTitle, SGRSideMargin, leading, CGRectGetMidY(row));
    resize(page, header, trailing.firstObject, filters);

    // The first pass that laid the header out, not the first pass at all: a page appearing lays out before
    // its controls have a size, and a line off that pass would say the header was left as Spotify's.
    static BOOL logged;
    if (!logged && header.window && face) {
        logged = YES;
        SGLog(@"redesign library: header %@, %lu controls at the trailing edge, avatar %@, chips %@",
              NSStringFromCGRect(header.frame), (unsigned long)trailing.count, face ? @"found" : @"not found",
              filters ? @"gone" : @"not found");
    }
}

static void layoutFolder(UIView *page) {
    UIView *header = childNamed(page, @"FolderHeaderView");
    if (!header) return;
    [header layoutIfNeeded];
    SGRLibraryClearScrim(header);
    UIView *filters = childNamed(header, @"YourLibraryHeaderContentFiltersView");
    vanish(filters);

    UIView *spotifyTitle = SGRFindByIdentifier(header, @"YourLibraryFolderHeader.title", &kFolderTitleKey);
    vanish(spotifyTitle);
    UIView *back = SGRFindByIdentifier(header, @"YourLibraryFolderHeader.back", &kBackKey);
    static const void *keys[] = {&kMenuKey, &kFolderPlusKey, &kPlayKey, &kPauseKey};
    NSMutableArray<UIView *> *trailing = controlsIn(header, @[
        @"YourLibraryFolderHeader.contextMenu", @"YourLibraryFolderHeader.plus",
        @"YourLibraryFolderHeader.play", @"YourLibraryFolderHeader.pause",
    ], keys);
    if (!trailing.count && !back) return;

    CGFloat trailingEdge = trailing.count ? placeTrailing(header, trailing) : header.bounds.size.width - kRowInset;
    UIView *row = back ?: trailing.firstObject;
    CGRect rowFrame = SGFrameIn(row, header);
    CGFloat leading = back ? CGRectGetMaxX(rowFrame) + SGRGrid : SGRSideMargin;
    layoutTitle(header, spotifyTitle, leading, trailingEdge, CGRectGetMidY(rowFrame));
    resize(page, header, row, filters);

    static BOOL logged;
    if (!logged && header.window && trailing.count) {
        logged = YES;
        SGLog(@"redesign library: folder header %@, back %@, %lu controls at the trailing edge, chips %@",
              NSStringFromCGRect(header.frame), back ? @"found" : @"not found", (unsigned long)trailing.count,
              filters ? @"gone" : @"not found");
    }
}

// Spotify works the list's top inset out from the header it had before the chips went, and sets it again
// whenever it lays the page out. The list keeps the one this file took instead, so the two never take turns
// setting it: a scroll view laying out again from every set of ours is a loop the page cannot settle out of.
%hook _TtC21YourLibrary_CommonKit25YourLibraryCollectionView
- (void)setContentInset:(UIEdgeInsets)inset {
    NSNumber *held = objc_getAssociatedObject(self, &kInsetKey);
    if (held) inset.top = held.doubleValue;
    %orig(inset);
}
%end

%hook _TtC28YourLibrary_YourLibraryXImpl15YourLibraryView
- (void)layoutSubviews {
    %orig;
    layoutRoot((UIView *)self);
}
%end

%hook _TtC22YourLibrary_FolderImpl10FolderView
- (void)layoutSubviews {
    %orig;
    layoutFolder((UIView *)self);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[
        @"_TtC28YourLibrary_YourLibraryXImpl15YourLibraryView",
        @"_TtC22YourLibrary_FolderImpl10FolderView",
        @"_TtC21YourLibrary_CommonKit25YourLibraryCollectionView",
        @"_TtC21YourLibrary_CommonKit35YourLibraryHeaderContentFiltersView",
        @"_TtC29ListeningActivity_ElementsKit21AdaptiveFaceContainer",
    ]);
}
