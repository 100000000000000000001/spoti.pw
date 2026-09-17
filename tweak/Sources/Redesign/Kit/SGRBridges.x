// The Kit's bridges into Spotify: the player's state, the now playing artwork and the link dispatcher.
// SGRBridges.h names the hooks and why they are the ones.
#import "Core/SGCore.h"
#import "Headers/SPTLinkDispatcherImplementation.h"
#import "Features/NowPlaying/NowPlaying.h"
#import "SGRBridges.h"
#import "SGRedesign.h"
#import "SGRRestyle.h"

NSString *SGRURIString(id uri) {
    if ([uri isKindOfClass:NSString.class]) return uri;
    if ([uri isKindOfClass:NSURL.class]) return ((NSURL *)uri).absoluteString;
    return nil;
}

#pragma mark - player state

static NSHashTable<id<SGRPlayerStateObserver>> *sg_stateObservers;
static SPTPlayerState *sg_playerState;
static NSString *sg_stateKey;
// Set once the now playing platform has reported; the Kit's own observer on the player stands down.
static BOOL sg_platformReported = NO;

void SGRAddPlayerStateObserver(id<SGRPlayerStateObserver> observer) {
    if (!observer) return;
    if (!sg_stateObservers) sg_stateObservers = [NSHashTable weakObjectsHashTable];
    [sg_stateObservers addObject:observer];
}

SPTPlayerState *SGRPlayerState(void) {
    return sg_playerState;
}

// What an observer is told about; the state object itself is new with every position report.
static NSString *keyOf(SPTPlayerState *state) {
    SPTPlayerOptions *options = [state respondsToSelector:@selector(options)] ? state.options : nil;
    BOOL shuffling = [options respondsToSelector:@selector(shufflingContext)] && options.shufflingContext;
    return [NSString stringWithFormat:@"%@|%@|%d%d%d%d", SGRURIString(state.track.URI), SGRURIString(state.contextURI),
            state.isPaused, state.isPlaying, [state respondsToSelector:@selector(isLoading)] && state.isLoading, shuffling];
}

static void publish(SPTPlayerState *state) {
    sg_playerState = state;
    NSString *key = keyOf(state);
    if ([key isEqualToString:sg_stateKey]) return;
    sg_stateKey = key;
    for (id<SGRPlayerStateObserver> observer in sg_stateObservers.allObjects) [observer playerStateDidChange:state];
}

static void report(id state, BOOL platform) {
    if (![state isKindOfClass:objc_getClass("SPTPlayerState")]) return;
    dispatch_block_t apply = ^{
        if (platform) sg_platformReported = YES;
        else if (sg_platformReported) return;
        publish(state);
    };
    if (NSThread.isMainThread) apply();
    else dispatch_async(dispatch_get_main_queue(), apply);
}

@interface SGRPlayerObserver : NSObject
@end

@implementation SGRPlayerObserver
- (void)player:(id)player stateDidChange:(id)state {
    report(state, NO);
}
@end

static SGRPlayerObserver *sg_kitObserver;

%group SGRPlayerStateHooks
%hook _TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation
- (void)player:(id)player stateDidChange:(id)state {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"redesign kit: player state from %@, a %@, on the main thread %d", [player class], [state class], NSThread.isMainThread);
    });
    report(state, YES);
}
%end

// Observers are added from several threads as the app starts; the first player seen is the one
// watched, the way KaraokeSource.x takes the first player the app asks.
%hook SPTEsperantoPlayer
- (void)addPlayerObserver:(id)observer {
    %orig;
    id player = self;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            sg_kitObserver = [SGRPlayerObserver new];
            [(id<SPTPlayer>)player addPlayerObserver:sg_kitObserver];
            id state = [player respondsToSelector:@selector(state)] ? [(id<SPTPlayer>)player state] : nil;
            if (state) report(state, NO);
        });
    });
}
%end
%end

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
    NSString *uri = SGRURIString(SGRPlayerState().track.URI);
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
@interface SGRBarArtworkWatcher : NSObject <SGRPlayerStateObserver>
@end

@implementation SGRBarArtworkWatcher {
    NSString *_track;
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *track = SGRURIString(state.track.URI);
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

#pragma mark - links

static __weak SPTLinkDispatcherImplementation *sg_linkDispatcher;

id SGRLinkDispatcher(void) {
    return sg_linkDispatcher;
}

BOOL SGROpenURI(NSURL *uri) {
    SPTLinkDispatcherImplementation *dispatcher = sg_linkDispatcher;
    if (!uri || ![dispatcher respondsToSelector:@selector(navigateToURI:options:interactionID:)]) return NO;
    [dispatcher navigateToURI:uri options:0 interactionID:nil];
    return YES;
}

// The dispatcher is a singleton the app builds at startup; this is the last call of its setup.
%hook SPTLinkDispatcherImplementation
- (void)setMainUILoaded:(BOOL)loaded {
    %orig;
    sg_linkDispatcher = (SPTLinkDispatcherImplementation *)self;
}
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
    %init;
    SGRequireClasses(@[@"SPTLinkDispatcherImplementation"]);
    if (!SGRedesignAnyOn()) return;
    %init(SGRPlayerStateHooks);
    SGRequireClasses(@[@"_TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation", @"SPTEsperantoPlayer", @"SPTPlayerState"]);
    if (!SGRedesignOn(@"player")) return;
    sg_barWatcher = [SGRBarArtworkWatcher new];
    SGRAddPlayerStateObserver(sg_barWatcher);
    %init(SGRBarArtworkHooks);
    SGRequireClasses(@[@"_TtC18NowPlaying_BarImpl27NowPlayingBarViewController"]);
}
