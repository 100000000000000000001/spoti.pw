// The Kit's bridge into Spotify: the now playing artwork. The player's state, its open and close and
// links are Shared's (Shared/Player/PlayerState.h, Shared/Player/PlayerEvents.h,
// Shared/Navigation/Links.h). SGRBridges.h names the hook and why it is the one.
#import "Core/SGCore.h"
#import "Shared/Player/PlayerEvents.h"
#import "SGRBridges.h"
#import "SGRedesign.h"
#import "SGRRestyle.h"

#pragma mark - now playing artwork

NSNotificationName const SGRNowPlayingArtworkDidChangeNotification = @"spotifyglass.redesign.nowPlayingArtworkDidChange";

static UIImage *sg_artwork;
static NSString *sg_artworkURI;
static SGRArtworkQuality sg_artworkQuality;

void SGRSetNowPlayingArtwork(UIImage *image, NSString *trackURI, SGRArtworkQuality quality) {
    if (!image) return;
    BOOL sameTrack = trackURI ? [trackURI isEqualToString:sg_artworkURI] : !sg_artworkURI;
    if (sameTrack && (image == sg_artwork || quality < sg_artworkQuality)) return;
    sg_artwork = image;
    sg_artworkURI = [trackURI copy];
    sg_artworkQuality = quality;
    [NSNotificationCenter.defaultCenter postNotificationName:SGRNowPlayingArtworkDidChangeNotification object:nil userInfo:@{
        @"image": image,
        @"trackURI": trackURI ?: @"",
        @"quality": @(quality),
    }];
}

UIImage *SGRNowPlayingArtwork(NSString **trackURI, NSString **identity) {
    if (trackURI) *trackURI = sg_artworkURI;
    if (identity) *identity = sg_artwork ? [NSString stringWithFormat:@"%@#%ld", sg_artworkURI ?: @"", (long)sg_artworkQuality] : nil;
    return sg_artwork;
}

static const CFTimeInterval kBarLead = 0.5;
static char kBarCardKey, kBarImageKey;
static __weak UIView *sg_barView;
// The bar's picture and when it appeared, and when the track last changed: a picture that was there
// well before the change is the last track's cover still, while one that turned up just before it
// was set by the same state the Kit is told about a moment later.
static __weak UIImage *sg_barImage;
static CFTimeInterval sg_barImageSince, sg_trackChangedAt;

static void publishBarArtwork(void) {
    UIView *card = SGRFindByIdentifier(sg_barView, @"SPTNowPlayingBar", &kBarCardKey);
    UIView *holder = SGRFindByIdentifier(card, @"Encore.ImageView", &kBarImageKey);
    UIImageView *cover = nil;
    for (UIView *sub in holder.subviews) {
        if ([sub isKindOfClass:UIImageView.class]) cover = (UIImageView *)sub;
    }
    UIImage *image = cover.image;
    NSString *uri = SGURIString(SGPlayerState().track.URI);
    if (!image || !uri) return;
    if (image != sg_barImage) {
        sg_barImage = image;
        sg_barImageSince = CACurrentMediaTime();
    }
    if (sg_barImageSince < sg_trackChangedAt - kBarLead) return;
    SGRSetNowPlayingArtwork(image, uri, SGRArtworkQualityLow);
}

// The bar sets its picture when the image has loaded, which lays nothing out, so a track change looks
// again a few times while the picture comes in.
@interface SGRBarArtworkWatcher : NSObject <SGPlayerStateObserver>
@end

@implementation SGRBarArtworkWatcher {
    NSString *_track;
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *track = SGURIString(state.track.URI);
    if (!track || [track isEqualToString:_track]) return;
    // The first track of the launch has no last cover to mistake for its own.
    if (_track) sg_trackChangedAt = CACurrentMediaTime();
    _track = track;
    for (NSNumber *delay in @[@0, @0.3, @1, @2.5]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ publishBarArtwork(); });
    }
}

@end

static SGRBarArtworkWatcher *sg_barWatcher;

%group SGRBarArtworkHooks
%hook _TtC18NowPlaying_BarImpl27NowPlayingBarViewController
- (void)viewDidLayoutSubviews {
    %orig;
    sg_barView = ((UIViewController *)self).viewIfLoaded;
    publishBarArtwork();
}
%end
%end

#pragma mark - the player's open and close

BOOL SGRPlayerIsTransitioning(void) {
    return SGPlayerTransitionEnds() > 0;
}

@interface SGRTransitionObservation : NSObject
@property (nonatomic, strong) NSArray *tokens;
@end

@implementation SGRTransitionObservation
- (void)dealloc {
    for (id token in self.tokens) [NSNotificationCenter.defaultCenter removeObserver:token];
}
@end

static char kTransitionKey;

void SGRObservePlayerTransition(id owner, void (^began)(id owner), void (^ended)(id owner)) {
    if (!owner) return;
    __weak id weakOwner = owner;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    NSMutableArray *tokens = [NSMutableArray array];
    if (began) {
        [tokens addObject:[center addObserverForName:SGPlayerTransitionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            id strongOwner = weakOwner;
            if (strongOwner) began(strongOwner);
        }]];
    }
    if (ended) {
        [tokens addObject:[center addObserverForName:SGPlayerTransitionEndedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            id strongOwner = weakOwner;
            if (strongOwner) ended(strongOwner);
        }]];
    }
    SGRTransitionObservation *observation = [SGRTransitionObservation new];
    observation.tokens = tokens;
    NSMutableArray *kept = objc_getAssociatedObject(owner, &kTransitionKey);
    if (!kept) {
        kept = [NSMutableArray array];
        objc_setAssociatedObject(owner, &kTransitionKey, kept, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [kept addObject:observation];
}

%ctor {
    if (!SGRedesignedUI()) return;
    sg_barWatcher = [SGRBarArtworkWatcher new];
    SGAddPlayerStateObserver(sg_barWatcher);
    %init(SGRBarArtworkHooks);
    SGRequireClasses(@[@"_TtC18NowPlaying_BarImpl27NowPlayingBarViewController"]);
}
