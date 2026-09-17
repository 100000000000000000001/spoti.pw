// Player redesign: of the cards under the player only lyrics is kept, and it has no card of its own when
// Apple Music style lyrics draw it: the lines sit straight on the field, with no edge where the card was;
// every other card (about the artist, videos, SongDNA, events, explore, credits, merch, anything Spotify
// adds later) reports no height, so the list closes up around it.
//
// An allow list rather than Declutter's block list: the server decides which cards a track gets, and a
// new kind should not turn up under a redesigned player. The collapse is the one Declutter/Declutter.x
// has shipped (the 24pt gaps between cards stay until the card list is filtered at the network, phase 2).
//
// Tree (trees/clean/player/01.txt:385, lyrics/01.txt:996-999): every card is an Element_List.CollectionViewCell
// whose first subview is an ElementContentView naming NowPlaying_ScrollAPI, then an ElementView, then
// the card's own root: Lyrics_CardElementImpl.CardView id=lyrics-card-view for lyrics,
// CreatorBiographyCardLayout, song-dna-npv-card and so on for the rest (all ten player snapshots). The
// cells of lists inside a card (WatchFeed's) name WatchFeed_ComponentAPI instead, so they are left to
// their card. The card's share button is id=lyrics-share-button (lyrics/01.txt:1009).
#import "Core/SGCore.h"
#import "Redesign/Kit/SGRKit.h"
#import "Features/Karaoke/Karaoke.h"
#import "Player.h"

// Below this a cell is collapsed, or still being laid out.
static const CGFloat kLivingHeight = 40;

static char kShareKey, kRevalidatedKey;
static __weak UIView *sg_lyricsCard;

// Spotify draws the lines still to come in black, for its card in the album colour (lyrics/01.txt:1054),
// so they read on the dark field only with Apple Music style lyrics drawn over them; without those the
// card keeps Spotify's own colour.
static BOOL clearWanted(void) {
    static BOOL wanted;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ wanted = SGFlag(SGKeyKaraokeLyrics, NO); });
    return wanted;
}

// In a window and not in a hidden cell: the list keeps the cells it has put aside for reuse in it, hidden
// (player/02.txt:521), each with the card it last held.
static BOOL showing(UIView *card) {
    if (!card.window) return NO;
    for (UIView *v = card; v; v = v.superview) {
        if (v.hidden) return NO;
        if ([v isKindOfClass:UICollectionView.class]) break;
    }
    return YES;
}

UIView *SGRPlayerLyricsCard(void) {
    UIView *card = sg_lyricsCard;
    return showing(card) ? card : nil;
}

// Whether the cell's content is the player's card list, remembered per content class.
static BOOL isPlayerCard(UIView *content) {
    static NSMutableSet<Class> *yes, *no;
    if (!yes) {
        yes = [NSMutableSet set];
        no = [NSMutableSet set];
    }
    Class cls = object_getClass(content);
    if (!cls || [no containsObject:cls]) return NO;
    if ([yes containsObject:cls]) return YES;
    BOOL player = [NSStringFromClass(cls) containsString:@"NowPlaying_ScrollAPI"];
    [(player ? yes : no) addObject:cls];
    return player;
}

static Class cardViewClass(void) {
    static Class cls;
    if (!cls) cls = NSClassFromString(@"_TtC22Lyrics_CardElementImpl8CardView");
    return cls;
}

static UIView *cellAround(UIView *view) {
    static Class cell;
    if (!cell) cell = NSClassFromString(@"_TtC12Element_List18CollectionViewCell");
    for (UIView *v = view.superview; v; v = v.superview) {
        if ([v isKindOfClass:cell]) return v;
    }
    return nil;
}

%hook _TtC12Element_List18CollectionViewCell
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)attributes {
    UICollectionViewLayoutAttributes *result = %orig;
    UIView *cell = (UIView *)self;
    UIView *content = cell.subviews.firstObject;
    if (!content || !isPlayerCard(content)) return result;
    UIView *root = content.subviews.firstObject.subviews.firstObject;
    if ([root isKindOfClass:cardViewClass()]) return result;
    result.size = CGSizeMake(result.size.width, 0);
    cell.clipsToBounds = YES;

    static NSMutableSet<NSString *> *logged;
    if (!logged) logged = [NSMutableSet set];
    NSString *name = root ? NSStringFromClass(root.class) : @"nothing yet";
    if (![logged containsObject:name]) {
        [logged addObject:name];
        SGLog(@"redesign player: collapsed card root %@ (%lu kinds so far)", name, (unsigned long)logged.count);
    }
    return result;
}
%end

%hook _TtC22Lyrics_CardElementImpl8CardView
- (void)layoutSubviews {
    %orig;
    UIView *card = (UIView *)self;
    UIView *cell = cellAround(card);
    if (!cell || !isPlayerCard(cell.subviews.firstObject)) return;
    // A card in a cell put aside never replaces one showing; a cell taken back from reuse keeps its card,
    // so the glyph is told on every pass (it returns at once when nothing changed).
    if (sg_lyricsCard != card && (showing(card) || !showing(sg_lyricsCard))) sg_lyricsCard = card;
    SGRPlayerLyricsCardChanged();

    UIView *share = SGRFindByIdentifier(card, @"lyrics-share-button", &kShareKey);
    SGRPlayerVanish(share);

    if (cell.bounds.size.height >= kLivingHeight) {
        objc_setAssociatedObject(cell, &kRevalidatedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // Spotify paints the cell the album colour again at every track change, which is no layout pass
        // of the card's; as the root of the lyrics card, Appearance/Repaint.x keeps it clear in between.
        if (clearWanted()) {
            sg_lyricsCardRoot = cell;
            SGStripBackgrounds(cell);
            static dispatch_once_t once;
            dispatch_once(&once, ^{ SGLog(@"redesign player: lyrics card cleared onto the field"); });
        }
        return;
    }
    // Sized before its card was in it, so it was collapsed as an unknown card: the list is asked once to
    // size it again, and not again until it has been seen at its height.
    if (objc_getAssociatedObject(cell, &kRevalidatedKey)) return;
    UICollectionView *list = (UICollectionView *)cell.superview;
    NSIndexPath *path = [list isKindOfClass:UICollectionView.class] ? [list indexPathForCell:(UICollectionViewCell *)cell] : nil;
    if (!path) return;
    objc_setAssociatedObject(cell, &kRevalidatedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UICollectionViewLayoutInvalidationContext *context = [[list.collectionViewLayout.class invalidationContextClass] new];
    [context invalidateItemsAtIndexPaths:@[path]];
    [list.collectionViewLayout invalidateLayoutWithContext:context];
    SGLog(@"redesign player: lyrics cell sized again at %@", path);
}

- (void)didMoveToWindow {
    %orig;
    if ((UIView *)self == sg_lyricsCard) SGRPlayerLyricsCardChanged();
}
%end

// A track without lyrics puts the card's cell aside without laying the card out or taking it out of
// the window, so the footer's glyph looks again while the next track's cards come in (the player
// waits up to 5 s for them).
@interface SGRPlayerCardsWatcher : NSObject <SGRPlayerStateObserver>
@end

@implementation SGRPlayerCardsWatcher {
    NSString *_track;
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *track = SGRURIString(state.track.URI);
    if (!track || [track isEqualToString:_track]) return;
    _track = track;
    for (NSNumber *delay in @[@1, @3, @6]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ SGRPlayerLyricsCardChanged(); });
    }
}

@end

static SGRPlayerCardsWatcher *sg_cardsWatcher;

%ctor {
    if (!SGRedesignOn(@"player")) return;
    %init;
    sg_cardsWatcher = [SGRPlayerCardsWatcher new];
    SGRAddPlayerStateObserver(sg_cardsWatcher);
    SGRequireClasses(@[
        @"_TtC12Element_List18CollectionViewCell",
        @"_TtC22Lyrics_CardElementImpl8CardView",
    ]);
}
