// The native look's Apple Music style lyrics view, over Spotify's full screen lyrics page
// (KaraokePage.x) and, compact, over the card under the player (Native/Player/KaraokeCard.x). The
// lines and the clock are Shared/Lyrics/Lyrics.h's.
#import <UIKit/UIKit.h>
#import "Shared/Lyrics/Lyrics.h"

@interface SGKaraokeView : UIView
// Compact is the card under the player: Spotify's own type size, no seeking by tap and no margin of
// its own, since the card already insets what it holds. initWithFrame: is the full screen page.
- (instancetype)initWithFrame:(CGRect)frame compact:(BOOL)compact;
// Hides Spotify's own lyrics next to this view while it has lyrics to show, and brings them back when not.
- (void)syncSiblings;
@end
