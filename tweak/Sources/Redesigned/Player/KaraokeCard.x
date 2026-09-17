// The same Apple Music style lyrics on the card under the player, so the card sweeps word by word
// rather than scrolling whole lines while the page it expands into sweeps. It is the page's view in
// compact: the card is a seventh of the height, so it takes Spotify's own type size and spacing.
//
// The host is Lyrics_CardElementImpl.CardContentView, the card's own content view. The table inside
// it, Lyrics_TextElementImpl.LyricsTextView, is the wrong thing to hook: the full screen page is
// built from that same class, and KaraokePage.x is already over it there. CardContentView belongs
// to the card alone, and is still in the tree while the page is open, behind it.
//
// The view is laid over rather than swapped in, as on the page: Spotify's table keeps running
// underneath and comes back the moment a track has no synced lyrics. It takes no touches, so the
// tap that opens the full screen page is still Spotify's to answer.
#import "Core/SGCore.h"
#import "Redesigned/Lyrics/SGRKaraokeView.h"

// Below this the card is collapsed, by PlayerCards.x or while it is still being laid out.
static const CGFloat kLivingHeight = 40;

static char kKaraokeKey;

%hook _TtC22Lyrics_CardElementImpl15CardContentView
- (void)layoutSubviews {
    %orig;
    UIView *host = (UIView *)self;
    if (host.bounds.size.height < kLivingHeight) return;
    SGRKaraokeView *view = objc_getAssociatedObject(host, &kKaraokeKey);
    if (!view) {
        SGLog(@"karaoke: card laid out, playing %@", SGKaraokePlayingTrack());
        view = [[SGRKaraokeView alloc] initWithFrame:host.bounds compact:YES];
        objc_setAssociatedObject(host, &kKaraokeKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (view.superview == host) [host bringSubviewToFront:view];
    else [host addSubview:view];
    view.frame = host.bounds;
    [view syncSiblings];
}
%end

%ctor {
    if (!SGRedesignedUI() || !SGFlag(SGKeyKaraokeLyrics, NO)) return;
    %init;
    SGRequireClasses(@[@"_TtC22Lyrics_CardElementImpl15CardContentView"]);
}
