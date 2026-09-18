// A mock of Spotify's full screen player under its own class names and accessibility identifiers, built
// from trees/clean/player/01.txt, so Redesigned/Player's lyrics state can be laid out, animated and
// looked at on the Mac. Tapping the lyrics glyph in the footer works exactly as it does on the phone;
// the harness also toggles it once by itself so a screenshot catches each state.
#import <UIKit/UIKit.h>
#import "Shared/Lyrics/Lyrics.h"
#import "Redesigned/Player/Player.h"

void SGRHarnessSetArtwork(UIImage *image);
void SGRHarnessPlayFrom(NSInteger ms);

#pragma mark - Spotify's classes, by name

@interface _TtC19NowPlaying_ViewImpl24NowPlayingViewController : UIViewController @end
@implementation _TtC19NowPlaying_ViewImpl24NowPlayingViewController @end

@interface _TtC20NowPlaying_ModesImpl23InformationElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl23InformationElementsUnit @end

@interface _TtC20NowPlaying_ModesImpl19DurationElementUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl19DurationElementUnit @end

@interface _TtC20NowPlaying_ModesImpl20FloatingElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl20FloatingElementsUnit @end

@interface _TtC20NowPlaying_ModesImpl18FooterElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl18FooterElementsUnit @end

@interface _TtC21NowPlaying_ScrollImpl23NPVScrollViewController : UIViewController @end
@implementation _TtC21NowPlaying_ScrollImpl23NPVScrollViewController @end

@interface _TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView : UICollectionView @end
@implementation _TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView @end

@interface _TtC28NowPlaying_ContentLayersImpl16CoverArtCellImpl : UIView @end
@implementation _TtC28NowPlaying_ContentLayersImpl16CoverArtCellImpl @end

@interface _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView : UIView
- (void)handleTap;
@end
@implementation _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView
- (void)handleTap {}
@end

@interface _TtC22Lyrics_NPVContainerKit19LyricsContainerView : UIView @end
@implementation _TtC22Lyrics_NPVContainerKit19LyricsContainerView @end

@interface MockEncoreButton : UIControl @end
@implementation MockEncoreButton @end

#pragma mark - building the tree

static UIView *box(UIView *parent, Class cls, CGRect frame, NSString *identifier) {
    UIView *view = [[cls alloc] initWithFrame:frame];
    view.accessibilityIdentifier = identifier;
    [parent addSubview:view];
    return view;
}

static UILabel *marquee(UIView *parent, CGRect frame, NSString *text, CGFloat size, UIColor *color, NSString *identifier) {
    UIView *clip = box(parent, UIView.class, frame, identifier);
    clip.clipsToBounds = YES;
    UILabel *inner = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 900, frame.size.height)];
    inner.text = text;
    inner.font = [UIFont systemFontOfSize:size weight:UIFontWeightBold];
    inner.textColor = color;
    [inner sizeToFit];
    [clip addSubview:inner];
    return inner;
}

static UIView *glyphButton(UIView *parent, CGRect frame, NSString *symbol, NSString *identifier) {
    UIView *button = box(parent, MockEncoreButton.class, frame, identifier);
    UIImageView *glyph = [[UIImageView alloc] initWithFrame:CGRectInset(button.bounds, 10, 10)];
    glyph.image = [UIImage systemImageNamed:symbol];
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    glyph.tintColor = UIColor.whiteColor;
    [button addSubview:glyph];
    return button;
}

static UIImage *artwork(void) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(354, 354)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {0.11, 0.06, 0.35, 1, 0.83, 0.15, 0.62, 1};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, NULL, 2);
        CGContextDrawLinearGradient(ctx.CGContext, gradient, CGPointZero, CGPointMake(354, 354), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        [[UIColor colorWithWhite:1 alpha:0.9] set];
        [@"LOOSE\nCANON" drawAtPoint:CGPointMake(28, 28) withAttributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:44 weight:UIFontWeightHeavy],
            NSForegroundColorAttributeName: [UIColor colorWithRed:1 green:0.92 blue:0.2 alpha:1],
        }];
    }];
}

// A song with words timed inside each line, the shape SGRKaraokeView draws.
static void loadLyrics(void) {
    NSArray<NSString *> *texts = @[
        @"Who got the 808 under the 809",
        @"Making everybody jump?",
        @"Easy, I'm motivated",
        @"I got the feeling this is overrated",
        @"Give me the respect or give me nothing",
        @"Running up the hill with a heavy load",
        @"Tell them that the kid never folded",
        @"Every single verse was a promise kept",
        @"Nobody was there when it started",
        @"Now everybody wanna say they knew",
    ];
    NSMutableArray<SGKaraokeLine *> *lines = [NSMutableArray array];
    NSInteger at = 0;
    for (NSString *text in texts) {
        NSArray<NSString *> *words = [text componentsSeparatedByString:@" "];
        NSMutableArray<SGKaraokeWord *> *built = [NSMutableArray array];
        NSInteger cursor = at;
        for (NSString *word in words) {
            SGKaraokeWord *w = [SGKaraokeWord new];
            w.text = word;
            w.start = cursor;
            cursor += 260 + word.length * 40;
            w.end = cursor;
            [built addObject:w];
        }
        SGKaraokeLine *line = [SGKaraokeLine new];
        line.words = built;
        line.start = at;
        line.end = cursor;
        [lines addObject:line];
        at = cursor + 400;
    }
    SGKaraokeKeepLines(@"harness", lines);
}

#pragma mark - the harness

@interface SGRHarnessDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SGRHarnessDelegate {
    NSArray<UIViewController *> *_units;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    loadLyrics();
    SGRHarnessPlayFrom(2400);
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor colorWithRed:0.09 green:0.07 blue:0.17 alpha:1];
    self.window.rootViewController = root;

    CGFloat W = root.view.bounds.size.width, H = root.view.bounds.size.height;
    // The player's own numbers are the tree's 402x874; the simulator's screen is whatever it is, so the
    // rows are placed as shares of it, the way Spotify's layout puts them.
    CGFloat headerTop = 62, headerHeight = 48;
    CGFloat bandTop = headerTop + headerHeight;
    CGFloat bottomHeight = 236 + 44;                 // the tree's rows plus a volume row, as the phone has it
    CGFloat bottomTop = H - bottomHeight - 61.33;
    CGFloat bandHeight = bottomTop - bandTop;
    CGFloat coverSide = MIN(354, W - 48);

    // NPVScrollViewController: the list the player is the header of.
    UIView *page = box(root.view, UIView.class, root.view.bounds, nil);
    UIScrollView *list = [[UIScrollView alloc] initWithFrame:page.bounds];
    list.accessibilityIdentifier = @"scrolling_npv_collection_view_accessibility_identifier";
    list.contentSize = CGSizeMake(W, H + 326);       // the player and a card's worth of cards under it
    [page addSubview:list];
    UIViewController *scrollUnit = [_TtC21NowPlaying_ScrollImpl23NPVScrollViewController new];
    scrollUnit.view = page;

    UIView *host = box(list, UIView.class, CGRectMake(0, 0, W, H), @"SPTNowPlayingView");

    // the content layers: the sideways list of covers
    UIView *layers = box(host, UIView.class, host.bounds, nil);
    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    UICollectionView *covers = [[_TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView alloc]
                                initWithFrame:layers.bounds collectionViewLayout:flow];
    covers.accessibilityIdentifier = @"nowplaying-contentlayer-collectionview";
    covers.backgroundColor = UIColor.clearColor;
    [layers addSubview:covers];
    UIView *cell = box(covers, _TtC28NowPlaying_ContentLayersImpl16CoverArtCellImpl.class, covers.bounds, @"nowplaying-contentlayer-cell-0");
    UIView *band = box(cell, UIView.class, CGRectMake(0, bandTop, W, bandHeight), nil);
    UIView *inner = box(band, UIView.class, CGRectMake(24, 8, W - 48, bandHeight - 16), nil);
    UIView *tilt = box(inner, _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView.class,
                       CGRectMake(0, round((inner.bounds.size.height - coverSide) / 2), coverSide, coverSide), nil);
    tilt.accessibilityLabel = @"Inspect cover art";
    UIView *coverElement = box(tilt, UIView.class, tilt.bounds, nil);
    UIImage *picture = artwork();
    SGRHarnessSetArtwork(picture);
    UIImageView *cover = [[UIImageView alloc] initWithFrame:coverElement.bounds];
    cover.image = picture;
    cover.contentMode = UIViewContentModeScaleAspectFill;
    [coverElement addSubview:cover];
    box(inner, _TtC22Lyrics_NPVContainerKit19LyricsContainerView.class, CGRectMake(0, inner.bounds.size.height, coverSide, 0), nil);

    // the header row
    UIView *header = box(host, UIStackView.class, CGRectMake(0, headerTop, W, headerHeight), nil);
    glyphButton(header, CGRectMake(12, 0, 48, 48), @"chevron.down", @"now-playing-minimize-button");
    glyphButton(header, CGRectMake(W - 60, 0, 48, 48), @"ellipsis", @"Context menu");

    // the bottom stack: information, duration, controls, volume, footer
    UIView *bottom = box(host, UIStackView.class, CGRectMake(0, bottomTop, W, bottomHeight), @"npv.bottomStackView");

    UIView *floatingView = box(bottom, UIView.class, CGRectMake(0, -32, W, 32), nil);
    UIView *chip = box(floatingView, UIView.class, CGRectMake(24, 0, 148, 32), nil);
    chip.backgroundColor = [UIColor colorWithWhite:1 alpha:0.16];
    chip.layer.cornerRadius = 16;
    UILabel *chipLabel = [[UILabel alloc] initWithFrame:chip.bounds];
    chipLabel.text = @"  \u25B6  Switch to video";
    chipLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    chipLabel.textColor = UIColor.whiteColor;
    [chip addSubview:chipLabel];

    UIView *infoView = box(bottom, UIView.class, CGRectMake(0, 0, W, 64), nil);
    UIView *infoRow = box(infoView, UIStackView.class, CGRectMake(12, 8, W - 24, 48), nil);
    UIView *infoInner = box(infoRow, UIStackView.class, infoRow.bounds, nil);
    box(infoInner, UIView.class, CGRectMake(0, 24, 0, 0), nil);          // Spotify's own mini cover, unused
    box(infoInner, UIView.class, CGRectMake(0, 24, 12, 0), nil);         // the spacer after it
    CGFloat titleWidth = infoInner.bounds.size.width - 12 - 60;
    UIView *titleElement = box(infoInner, UIView.class, CGRectMake(12, 2.33, titleWidth, 43.33), nil);
    UIView *titleContainer = box(titleElement, UIView.class, titleElement.bounds, nil);
    marquee(titleContainer, CGRectMake(0, 0, titleWidth, 25.33), @"We Are The People - southstar Remix (Extended)", 21,
            UIColor.whiteColor, @"now-playing-title-label");
    marquee(titleContainer, CGRectMake(0, 25.33, titleWidth, 18), @"Canon", 13,
            [UIColor colorWithWhite:1 alpha:0.7], @"now-playing-subtitle-label");
    glyphButton(infoInner, CGRectMake(infoInner.bounds.size.width - 48, 0, 48, 48), @"star", @"Components.UI.AddToButton");

    UIView *durationView = box(bottom, UIView.class, CGRectMake(0, 64, W, 40), nil);
    UIView *track = box(durationView, UIView.class, CGRectMake(24, 8, W - 48, 6), nil);
    track.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
    track.layer.cornerRadius = 3;
    UIView *played = box(track, UIView.class, CGRectMake(0, 0, (W - 48) * 0.22, 6), nil);
    played.backgroundColor = [UIColor colorWithWhite:1 alpha:0.85];
    played.layer.cornerRadius = 3;

    UIView *controls = box(bottom, UIView.class, CGRectMake(0, 104, W, 88), nil);
    glyphButton(controls, CGRectMake(W / 2 - 130, 20, 48, 48), @"backward.fill", nil);
    glyphButton(controls, CGRectMake(W / 2 - 24, 14, 48, 60), @"pause.fill", nil);
    glyphButton(controls, CGRectMake(W / 2 + 82, 20, 48, 48), @"forward.fill", nil);

    UIView *volume = box(bottom, UIView.class, CGRectMake(0, 192, W, 44), nil);
    UIView *volumeTrack = box(volume, UIView.class, CGRectMake(44, 19, W - 88, 6), nil);
    volumeTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
    volumeTrack.layer.cornerRadius = 3;

    UIView *footerView = box(bottom, UIView.class, CGRectMake(0, 236, W, 44), nil);
    UIView *footerRow = box(footerView, UIStackView.class, CGRectMake(12, 0, W - 24, 44), nil);
    UIView *connect = box(footerRow, UIView.class, CGRectMake(0, 4, 153.67, 36), nil);
    UIView *connectHolder = box(connect, UIView.class, connect.bounds, @"Components.ConnectButtonOutputSwitcher");
    UIImageView *connectGlyph = [[UIImageView alloc] initWithFrame:CGRectMake(0, 8, 19, 19)];
    connectGlyph.image = [UIImage systemImageNamed:@"airpods.pro"];
    connectGlyph.tintColor = UIColor.whiteColor;
    [connectHolder addSubview:connectGlyph];
    glyphButton(footerRow, CGRectMake(279, 0, 44, 44), @"square.and.arrow.up", @"ShareButtonNowPlayingView");
    glyphButton(footerRow, CGRectMake(323, 6, 47, 32), @"list.bullet", @"QueueButtonNowPlaying");

    [self.window makeKeyAndVisible];

    UIViewController *info = [_TtC20NowPlaying_ModesImpl23InformationElementsUnit new];
    info.view = infoView;
    UIViewController *duration = [_TtC20NowPlaying_ModesImpl19DurationElementUnit new];
    duration.view = durationView;
    UIViewController *floating = [_TtC20NowPlaying_ModesImpl20FloatingElementsUnit new];
    floating.view = floatingView;
    UIViewController *footer = [_TtC20NowPlaying_ModesImpl18FooterElementsUnit new];
    footer.view = footerView;
    UIViewController *player = [_TtC19NowPlaying_ViewImpl24NowPlayingViewController new];
    player.view = host;
    _units = @[info, duration, floating, footer, scrollUnit, player];
    [self layOut];
    // Spotify lays its units out again as a track's elements arrive, which is what the redesign's
    // transforms and narrowed labels have to survive.
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t) { [self layOut]; }];

    NSLog(@"[harness] lyrics available: %d", SGRPlayerLyricsAvailable());
    // With the lines up, the row that rose into them must still be Spotify's to touch, and the lines
    // themselves must take the tap that seeks.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIView *star = nil;
        for (UIView *v in infoInner.subviews) if ([v.accessibilityIdentifier isEqualToString:@"Components.UI.AddToButton"]) star = v;
        CGPoint onStar = [self.window convertPoint:CGPointMake(CGRectGetMidX(star.bounds), CGRectGetMidY(star.bounds)) fromView:star];
        CGPoint onTitle = [self.window convertPoint:CGPointMake(40, 12) fromView:titleElement];
        CGPoint onLines = CGPointMake(W / 2, H * 0.45);
        NSLog(@"[harness] hit on the star: %@", NSStringFromClass([self.window hitTest:onStar withEvent:nil].class));
        NSLog(@"[harness] hit on the title: %@", NSStringFromClass([self.window hitTest:onTitle withEvent:nil].class));
        NSLog(@"[harness] hit on the lines: %@", NSStringFromClass([self.window hitTest:onLines withEvent:nil].class));
    });
    // Opened, closed and opened again, so a screenshot can be taken of each state and of the move itself.
    for (NSNumber *at in @[@2, @6, @10]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(at.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"[harness] %@ the lyrics", SGRPlayerLyricsOpen() ? @"closing" : @"opening");
            SGRPlayerToggleLyrics();
        });
    }
    return YES;
}

- (void)layOut {
    for (UIViewController *unit in _units) [unit viewDidLayoutSubviews];
}

@end

// Before every %ctor, so the redesign's gate reads on.
__attribute__((constructor(101))) static void sgr_harnessDefaults(void) {
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"spotifyglass.redesign"];
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(SGRHarnessDelegate.class));
    }
}
