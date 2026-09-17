// Artist page redesign, the Music list (RedesignArtist.h): Spotify's own list with only the music left on
// it, under the Kit's section headers, its rows restyled for the field.
//
// Trees (trees/clean/artist/01-13.txt): every row of the Music list is an Element_List CollectionViewCell
// holding a Creator_CreatorPageImpl LCR_Structure element, NoData or NeedsData by its content view's class.
// Spotify's own accessibility identifiers say what a cell is, in any language:
//     Components.UI.SectionHeadingHome             a section's heading
//     Components.UI.LikedSongs.Row                 songs you liked (and its 0pt twin, songs available offline)
//     Components.UI.RetrievalRowElementUI_Loaded   a popular track, the sixth with the See more footer, or a
//                                                  popular release
//     Components.UI.ListSectionFooter.Button       See discography
//     Components.UI.UpcomingReleaseRow             the release countdown
//     Components.UI.RetrievalRowLoadingElementUI   the loading row standing in for one of those
//     Components.UI.PinnedItem*, CreatorBiographyCard*, MusicVideoShelfHeader*, Music-Videos.*, HomeCard
//                                                  artist pick, about, music videos, and the carousels of
//                                                  featuring, artist playlists, fans also like and appears on
// and a NoData cell with no identifier and nothing in it is the spacer between two sections. What is not
// music answers height 0 from preferredLayoutAttributesFittingAttributes:, as Features/Artist/Artist.x
// proved, and a section no rule knows is left out.
//
// A heading comes right before the cell of its section (01.txt: Artist pick at 468.7, its card at 505.3) but
// is sized before that cell exists. So a heading stays when it is the list's first (Popular) or the cell
// under it is already known to be music, and otherwise waits collapsed; sizing the cell under it settles
// the heading, which is sized again when the answer changed. What a heading's section turned out to be is
// remembered by its title for the rest of the launch, so the next artist page in the same language has
// the answer before the cell under it is sized. The answer still comes from the cells, never from the words.
#import <objc/runtime.h>
#import "Core/SGCore.h"
#import "Redesign/Kit/SGRKit.h"
#import "RedesignArtist.h"

typedef NS_ENUM(NSInteger, SGArtistCell) {
    SGArtistCellPending,   // a NeedsData cell with nothing in it yet: Spotify's height until it fills
    SGArtistCellHeading,
    SGArtistCellMusic,
    SGArtistCellLiked,
    SGArtistCellLoading,
    SGArtistCellSpacer,
    SGArtistCellOther,     // everything else, collapsed
};

static Class sg_listViewClass, sg_headingButtonClass, sg_gradientClass;
static BOOL sg_hideLiked;
static NSMutableDictionary<NSString *, NSNumber *> *sg_learntHeadings;   // title: kept or not
static char kListKey, kFadedRowKey, kHiddenGradientKey;

// A cell's walk ends at its first telling identifier, a few views down; this bounds one that has none.
static const NSUInteger kWalkLimit = 160;
static NSString *const kFadeName = @"spotifyglass.artistFooterFade";

@interface SGArtistWeak : NSObject
@property (nonatomic, weak) UIView *view;
@end
@implementation SGArtistWeak
@end

static UIView *weakGet(id object, const void *key) {
    return ((SGArtistWeak *)objc_getAssociatedObject(object, key)).view;
}

static void weakSet(id object, const void *key, UIView *view) {
    SGArtistWeak *box = nil;
    if (view) {
        box = [SGArtistWeak new];
        box.view = view;
    }
    objc_setAssociatedObject(object, key, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - what a cell is

static SGArtistCell kindOfIdentifier(NSString *identifier) {
    static NSSet<NSString *> *music;
    static NSArray<NSString *> *other;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // EmptyReleasesSectionElement is in the binary's strings only, for an artist with no releases.
        music = [NSSet setWithArray:@[@"Components.UI.RetrievalRowElementUI_Loaded", @"Components.UI.ListSectionFooter.Button",
                                      @"Components.UI.UpcomingReleaseRow", @"Components.UI.EmptyReleasesSectionElement"]];
        other = @[@"Components.UI.PinnedItem", @"Components.UI.CreatorBiographyCard", @"Components.UI.MusicVideoShelfHeader",
                  @"Music-Videos.", @"Components.UI.HomeCard", @"Merch."];
    });
    if ([identifier isEqualToString:@"Components.UI.SectionHeadingHome"]) return SGArtistCellHeading;
    if ([identifier isEqualToString:@"Components.UI.LikedSongs.Row"]) return SGArtistCellLiked;
    if ([music containsObject:identifier]) return SGArtistCellMusic;
    if ([identifier isEqualToString:@"Components.UI.RetrievalRowLoadingElementUI"]) return SGArtistCellLoading;
    for (NSString *prefix in other) {
        if ([identifier hasPrefix:prefix]) return SGArtistCellOther;
    }
    return SGArtistCellPending;
}

// Identifiers every kind of cell carries, which say nothing about the section.
static BOOL isGeneric(NSString *identifier) {
    return [identifier hasPrefix:@"Encore."] || [identifier hasPrefix:@"EncoreConsumerMobile.View."] || [identifier hasSuffix:@"-internal"];
}

// Depth first, stopping at the first identifier with a rule; `unknown` gets the first other identifier of a
// cell no rule decided.
static SGArtistCell classify(UICollectionViewCell *cell, NSString **unknown) {
    UIView *content = cell.contentView;
    // The state is in the element content view's class (01.txt: ElementContentView<…9NeedsData>), which is
    // the cell's only child and so its content view (a content configuration's view); its first child
    // too, should UIKit keep a content view of its own around it.
    BOOL needsData = [NSStringFromClass(content.class) containsString:@"9NeedsData"]
                     || [NSStringFromClass(content.subviews.firstObject.class) containsString:@"9NeedsData"];
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:content];
    NSUInteger visited = 0;
    BOOL nested = NO;
    NSString *first = nil;
    while (stack.count && visited < kWalkLimit) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        // The Kit's own header, left in a heading cell Spotify reuses for another row.
        if ([view isKindOfClass:SGRSectionHeader.class]) continue;
        visited++;
        NSString *identifier = view.accessibilityIdentifier;
        if (identifier.length) {
            SGArtistCell kind = kindOfIdentifier(identifier);
            if (kind != SGArtistCellPending) return kind;
            if (!first && !isGeneric(identifier)) first = identifier;
        }
        // A carousel's cards are a list of their own, and the carousel is not music.
        if ([view isKindOfClass:UICollectionView.class]) {
            nested = YES;
            continue;
        }
        for (UIView *sub in view.subviews.reverseObjectEnumerator) [stack addObject:sub];
    }
    if (unknown) *unknown = first;
    if (nested || first) return SGArtistCellOther;
    if (needsData) return SGArtistCellPending;
    // Element content view > element view > one bare UIView (01.txt: the 16pt cells), and one more level
    // should the content view wrap the element content view.
    return visited <= 4 ? SGArtistCellSpacer : SGArtistCellOther;
}

// Trees (01.txt): the title is the accessibility label of the heading's NoIntrinsicContentSizeButton.
static NSString *headingTitleIn(UIView *root) {
    __block NSString *title = nil;
    if (!root || !sg_headingButtonClass) return nil;
    SGForEachView(root, ^(UIView *view) {
        if (!title && [view isKindOfClass:sg_headingButtonClass] && view.accessibilityLabel.length) title = view.accessibilityLabel;
    });
    return title;
}

static BOOL settles(SGArtistCell kind) {
    return kind != SGArtistCellPending && kind != SGArtistCellLoading;
}

// The Kit's header draws its title 24pt down in title 2 bold (capped at XXXL); the heading gets that and
// a little room under it, never less than 56.
static CGFloat headingHeight(void) {
    UIFont *font = SGRFont(UIFontTextStyleTitle2, UIFontWeightBold, UIContentSizeCategoryExtraExtraExtraLarge);
    return MAX(56, ceil(24 + font.lineHeight + SGRGrid / 2));
}

static void logUnknown(NSString *identifier, CGFloat height) {
    static NSMutableSet<NSString *> *seen;
    if (!seen) seen = [NSMutableSet set];
    if (seen.count >= 12 || [seen containsObject:identifier]) return;
    [seen addObject:identifier];
    SGLog(@"artist: collapsed a cell no rule knows, first identifier %@, %.0f tall", identifier, height);
}

#pragma mark - the list

@interface SGArtistList : NSObject
@property (nonatomic, weak) UICollectionView *view;
- (CGFloat)heightOf:(UICollectionViewCell *)cell at:(NSIndexPath *)path fitting:(CGFloat)height;
- (void)willDisplay:(UICollectionViewCell *)cell at:(NSIndexPath *)path;
@end

@implementation SGArtistList {
    NSMutableDictionary<NSIndexPath *, NSNumber *> *_kinds;      // what each cell sized so far is
    NSMutableDictionary<NSIndexPath *, NSNumber *> *_settled;    // heading: kept or not, by the cell under it
    NSMutableDictionary<NSIndexPath *, NSNumber *> *_answered;   // heading: kept or not, as last sized
    NSMutableDictionary<NSIndexPath *, NSString *> *_titles;     // heading: its title
    NSUInteger _corrections;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _kinds = [NSMutableDictionary dictionary];
    _settled = [NSMutableDictionary dictionary];
    _answered = [NSMutableDictionary dictionary];
    _titles = [NSMutableDictionary dictionary];
    return self;
}

- (CGFloat)heightOf:(UICollectionViewCell *)cell at:(NSIndexPath *)path fitting:(CGFloat)height {
    NSString *unknown = nil;
    SGArtistCell kind = classify(cell, &unknown);
    [self record:kind at:path];
    // See more reconfigures its cell in place (the footer goes, the row stays), which sizes the cell again
    // but need not display it again.
    [self fadeFooterOf:cell music:kind == SGArtistCellMusic retry:NO];
    switch (kind) {
        case SGArtistCellHeading: {
            NSString *title = headingTitleIn(cell.contentView);
            _titles[path] = title;
            BOOL kept = [self headingKeptAt:path title:title];
            _answered[path] = @(kept);
            return kept ? headingHeight() : 0;
        }
        case SGArtistCellMusic:
            [self settleHeadingAbove:path kept:YES];
            return height;
        case SGArtistCellLiked:
            return sg_hideLiked ? 0 : height;
        case SGArtistCellOther:
            [self settleHeadingAbove:path kept:NO];
            if (unknown) logUnknown(unknown, height);
            return 0;
        case SGArtistCellSpacer:
            return 0;
        case SGArtistCellPending:
        case SGArtistCellLoading:
            return height;
    }
    return height;
}

- (void)record:(SGArtistCell)kind at:(NSIndexPath *)path {
    NSNumber *before = _kinds[path];
    _kinds[path] = @(kind);
    if (!before || before.integerValue == kind || !settles(before.integerValue) || !settles(kind)) return;
    // Something else sits at this index now (See more put five tracks in): what was learnt about it and
    // below it is stale.
    for (NSMutableDictionary<NSIndexPath *, id> *map in @[_kinds, _settled, _titles]) {
        NSMutableArray<NSIndexPath *> *stale = [NSMutableArray array];
        for (NSIndexPath *key in map) {
            if (key.section == path.section && (key.item > path.item || (map != (id)_kinds && key.item == path.item))) [stale addObject:key];
        }
        [map removeObjectsForKeys:stale];
    }
}

- (BOOL)headingKeptAt:(NSIndexPath *)path title:(NSString *)title {
    NSNumber *settled = _settled[path];
    if (settled) return settled.boolValue;
    NSNumber *below = _kinds[[NSIndexPath indexPathForItem:path.item + 1 inSection:path.section]];
    if (below && below.integerValue == SGArtistCellMusic) return YES;
    if (below && below.integerValue == SGArtistCellOther) return NO;
    NSNumber *learnt = title ? sg_learntHeadings[title] : nil;
    if (learnt) return learnt.boolValue;
    for (NSIndexPath *key in _kinds) {
        if (key.section == path.section && key.item < path.item && _kinds[key].integerValue == SGArtistCellHeading) return NO;
    }
    return YES;
}

- (void)settleHeadingAbove:(NSIndexPath *)path kept:(BOOL)kept {
    if (path.item == 0) return;
    NSIndexPath *above = [NSIndexPath indexPathForItem:path.item - 1 inSection:path.section];
    NSNumber *kind = _kinds[above];
    if (!kind || kind.integerValue != SGArtistCellHeading) return;
    _settled[above] = @(kept);
    NSString *title = _titles[above];
    if (title) sg_learntHeadings[title] = @(kept);
    NSNumber *answered = _answered[above];
    if (!answered || answered.boolValue == kept) return;
    [self resizeItemAt:above kept:kept];
}

// Self-sizing invalidation (iOS 16) sizes a shown cell again; a heading off screen is sized again when it
// scrolls in, and its layout item is invalidated meanwhile. After the current layout pass, not inside it.
- (void)resizeItemAt:(NSIndexPath *)path kept:(BOOL)kept {
    __weak UICollectionView *weakView = self.view;
    BOOL logged = _corrections++ < 3;
    dispatch_async(dispatch_get_main_queue(), ^{
        UICollectionView *view = weakView;
        if (!view || path.section >= view.numberOfSections || path.item >= [view numberOfItemsInSection:path.section]) return;
        UICollectionViewCell *cell = [view cellForItemAtIndexPath:path];
        if (logged) SGLog(@"artist: heading %ld %@ by the cell under it, %@", (long)path.item, kept ? @"kept" : @"collapsed", cell ? @"on screen" : @"off screen");
        if (cell && view.selfSizingInvalidation != UICollectionViewSelfSizingInvalidationDisabled) {
            [cell invalidateIntrinsicContentSize];
            return;
        }
        UICollectionViewLayout *layout = view.collectionViewLayout;
        UICollectionViewLayoutInvalidationContext *context = [[layout.class invalidationContextClass] new];
        [context invalidateItemsAtIndexPaths:@[path]];
        [layout invalidateLayoutWithContext:context];
    });
}

- (void)logSummarySoon {
    __weak SGArtistList *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SGArtistList *list = weakSelf;
        if (!list) return;
        NSUInteger counts[SGArtistCellOther + 1] = {0}, kept = 0;
        for (NSNumber *kind in list->_kinds.allValues) {
            if (kind.integerValue >= 0 && kind.integerValue <= SGArtistCellOther) counts[kind.integerValue]++;
        }
        for (NSNumber *answer in list->_answered.allValues) kept += answer.boolValue;
        SGLog(@"artist: list after 2 s: heading %lu (kept %lu), music %lu, liked %lu, loading %lu, pending %lu, spacer %lu, collapsed %lu, corrections %lu",
              (unsigned long)counts[SGArtistCellHeading], (unsigned long)kept, (unsigned long)counts[SGArtistCellMusic],
              (unsigned long)counts[SGArtistCellLiked], (unsigned long)counts[SGArtistCellLoading], (unsigned long)counts[SGArtistCellPending],
              (unsigned long)counts[SGArtistCellSpacer], (unsigned long)counts[SGArtistCellOther], (unsigned long)list->_corrections);
    });
}

#pragma mark - restyle

- (void)willDisplay:(UICollectionViewCell *)cell at:(NSIndexPath *)path {
    UICollectionView *view = self.view;
    if (SGIsBaseSurface(view.layer.backgroundColor)) view.layer.backgroundColor = NULL;
    SGArtistCell kind = classify(cell, NULL);
    if (kind == SGArtistCellHeading) {
        [self dressHeading:cell];
        // A heading settled while it had no visible cell (sized ahead of the scroll, then the row under it)
        // keeps its old size in the layout; the cell it finally shows in is sized again.
        NSNumber *settled = path ? _settled[path] : nil, *answered = path ? _answered[path] : nil;
        if (settled && answered && settled.boolValue != answered.boolValue) [self resizeItemAt:path kept:settled.boolValue];
    } else {
        for (UIView *sub in cell.contentView.subviews) {
            if ([sub isKindOfClass:SGRSectionHeader.class]) sub.hidden = YES;
        }
        if (kind != SGArtistCellSpacer && kind != SGArtistCellOther) SGRStyleSpotifyCell(cell.contentView);
    }
    [self fadeFooterOf:cell music:kind == SGArtistCellMusic retry:YES];
}

static BOOL shownIn(UIView *view, UIView *root) {
    if (CGRectGetWidth(view.bounds) <= 0) return NO;
    for (UIView *v = view; v && v != root; v = v.superview) {
        if (v.hidden) return NO;
    }
    return YES;
}

// Trees (01.txt): a section with somewhere to go shows Show all (id=Components.UI.NavigationButtonHome, an Encore tertiary
// button) in a passthrough view that is hidden otherwise (Popular).
- (void)dressHeading:(UICollectionViewCell *)cell {
    static char headingKey, showAllKey;
    UIView *spotify = SGRFindByIdentifier(cell.contentView, @"Components.UI.SectionHeadingHome", &headingKey);
    NSString *title = headingTitleIn(spotify);
    UIView *showAll = SGRFindByIdentifier(cell.contentView, @"Components.UI.NavigationButtonHome", &showAllKey);
    UIControl *target = [showAll isKindOfClass:UIControl.class] && shownIn(showAll, cell) ? (UIControl *)showAll : nil;
    if (spotify.alpha != 0) spotify.alpha = 0;
    if (spotify && !spotify.accessibilityElementsHidden) spotify.accessibilityElementsHidden = YES;
    SGRSectionHeader *header = [SGRSectionHeader headerInCell:cell title:title ?: @"" target:target];
    header.hidden = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"artist: section header \"%@\", show all %@", title, target ? NSStringFromClass(target.class) : @"none"); });
}

// The See more cell's gradient, found by level (01.txt, 08.txt: element content view > element view >
// clipping view > view > [the row element, GradientView, the footer element], four levels down); no
// other cell of the Music list carries one that high up, the biography card's is lower and collapsed.
static UIView *footerGradientIn(UIView *content) {
    NSArray<UIView *> *level = content ? @[content] : @[];
    for (NSUInteger depth = 0; depth <= 5 && level.count; depth++) {
        NSMutableArray<UIView *> *next = [NSMutableArray array];
        for (UIView *view in level) {
            if ([view isKindOfClass:sg_gradientClass]) return view;
            [next addObjectsFromArray:view.subviews];
        }
        level = next;
    }
    return nil;
}

// See more closes Popular with the sixth track fading out under the button (01.txt: the 88pt cell, the row
// element, a GradientView over all of it, then the footer element). The gradient is Spotify's base grey,
// a band on the field, so it goes and the row fades through a mask instead; both are put back when the
// cell comes back as anything else. A cell not laid out yet has a row of no size, so the mask is sized
// once more after the layout pass.
- (void)fadeFooterOf:(UICollectionViewCell *)cell music:(BOOL)music retry:(BOOL)retry {
    UIView *row = nil, *gradient = music && sg_gradientClass ? footerGradientIn(cell.contentView) : nil;
    NSArray<UIView *> *siblings = gradient.superview.subviews;
    NSUInteger index = gradient ? [siblings indexOfObjectIdenticalTo:gradient] : NSNotFound;
    if (index != NSNotFound && index > 0) row = siblings[index - 1];
    if (!row) gradient = nil;
    UIView *fadedRow = weakGet(cell, &kFadedRowKey), *hiddenGradient = weakGet(cell, &kHiddenGradientKey);
    if (fadedRow && fadedRow != row && [fadedRow.layer.mask.name isEqualToString:kFadeName]) fadedRow.layer.mask = nil;
    if (hiddenGradient && hiddenGradient != gradient && hiddenGradient.alpha == 0) hiddenGradient.alpha = 1;
    if (!row || !gradient) {
        if (fadedRow) weakSet(cell, &kFadedRowKey, nil);
        if (hiddenGradient) weakSet(cell, &kHiddenGradientKey, nil);
        return;
    }
    if (gradient.alpha != 0) gradient.alpha = 0;
    if (hiddenGradient != gradient) weakSet(cell, &kHiddenGradientKey, gradient);
    if (CGRectGetHeight(row.bounds) <= 0) {
        if (!retry) return;
        __weak SGArtistList *weakSelf = self;
        __weak UICollectionViewCell *weakCell = cell;
        dispatch_async(dispatch_get_main_queue(), ^{
            UICollectionViewCell *later = weakCell;
            if (later) [weakSelf fadeFooterOf:later music:classify(later, NULL) == SGArtistCellMusic retry:NO];
        });
        return;
    }
    CAGradientLayer *mask = [row.layer.mask.name isEqualToString:kFadeName] ? (CAGradientLayer *)row.layer.mask : nil;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!mask) {
        mask = [CAGradientLayer layer];
        mask.name = kFadeName;
        mask.colors = @[(id)UIColor.blackColor.CGColor, (id)UIColor.clearColor.CGColor];
        mask.locations = @[@0.2, @1];
        row.layer.mask = mask;
    }
    mask.frame = row.layer.bounds;
    [CATransaction commit];
    if (fadedRow != row) weakSet(cell, &kFadedRowKey, row);
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"artist: See more row faded, Spotify's gradient hidden"); });
}

@end

// The list of a redesigned artist page's Music tab, kept on its collection view; NSNull for any other list.
static SGArtistList *listOf(UICollectionView *view) {
    if (![view isKindOfClass:UICollectionView.class]) return nil;
    id known = objc_getAssociatedObject(view, &kListKey);
    if (known) return known == NSNull.null ? nil : known;
    UIView *listView = view.superview;
    // Not in its list view yet: asked again, not written off.
    if (!listView) return nil;
    // Only the first page of the tabs is Music (01.txt); a carousel inside a cell and the other tabs are left alone.
    if (![listView isKindOfClass:sg_listViewClass]) {
        objc_setAssociatedObject(view, &kListKey, NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return nil;
    }
    BOOL pending = NO;
    SGArtistPage *page = SGArtistPageOf(listView, &pending);
    if (!page || listView.superview.subviews.firstObject != listView) {
        if (!pending && view.window) objc_setAssociatedObject(view, &kListKey, NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return nil;
    }
    SGArtistList *list = [SGArtistList new];
    list.view = view;
    objc_setAssociatedObject(view, &kListKey, list, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (SGIsBaseSurface(view.layer.backgroundColor)) view.layer.backgroundColor = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"artist: Music list found, %lu pages beside it", (unsigned long)listView.superview.subviews.count);
        [list logSummarySoon];
    });
    return list;
}

%hook _TtC12Element_List18CollectionViewCell
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)attributes {
    UICollectionViewLayoutAttributes *result = %orig;
    UICollectionViewCell *cell = (UICollectionViewCell *)self;
    NSIndexPath *path = attributes.indexPath;
    SGArtistList *list = path ? listOf((UICollectionView *)cell.superview) : nil;
    if (!list) return result;
    CGFloat height = [list heightOf:cell at:path fitting:result.size.height];
    if (height == result.size.height) return result;
    result.size = CGSizeMake(result.size.width, height);
    if (height == 0) cell.clipsToBounds = YES;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"artist: first cell resized, %.0f tall", height); });
    return result;
}
%end

%hook _TtC32CreativeWorkPlatform_TemplateKit28CreativeWorkTemplateListView
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
    [listOf(collectionView) willDisplay:cell at:indexPath];
}
%end

%ctor {
    if (!SGRedesignOn(@"artist")) return;
    sg_listViewClass = NSClassFromString(@"_TtC32CreativeWorkPlatform_TemplateKit28CreativeWorkTemplateListView");
    sg_headingButtonClass = NSClassFromString(@"_TtCOOOE11Home_ECMKitO19LegacyUI_ECMCoreKit10Components18SectionHeadingHome2UI7Private28NoIntrinsicContentSizeButton");
    sg_gradientClass = NSClassFromString(@"_TtC19LegacyUI_ECMCoreKit12GradientView");
    sg_hideLiked = SGHidden(SGKeyRedesignArtistHideLikedSongs);
    sg_learntHeadings = [NSMutableDictionary dictionary];
    %init;
    SGRequireClasses(@[
        @"_TtC12Element_List18CollectionViewCell",
        @"_TtC32CreativeWorkPlatform_TemplateKit28CreativeWorkTemplateListView",
        @"_TtCOOOE11Home_ECMKitO19LegacyUI_ECMCoreKit10Components18SectionHeadingHome2UI7Private28NoIntrinsicContentSizeButton",
        @"_TtC19LegacyUI_ECMCoreKit12GradientView",
    ]);
}
