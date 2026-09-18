// A mock of Spotify's playlist page under its own class names and accessibility identifiers, built from
// trees/clean/playlist/01.txt, so Redesigned/Playlist can be laid out and looked at on the Mac.
#import <UIKit/UIKit.h>

#pragma mark - Spotify's classes, by name

@interface _TtC35ListUXPlatform_FreeTierPlaylistImpl17FTPViewController : UIViewController @end
@implementation _TtC35ListUXPlatform_FreeTierPlaylistImpl17FTPViewController @end

@interface _TtC35ListUXPlatform_FreeTierPlaylistImpl32FTPTouchCancellingCollectionView : UIScrollView @end
@implementation _TtC35ListUXPlatform_FreeTierPlaylistImpl32FTPTouchCancellingCollectionView @end

@interface SPTFreeTierPlaylistEncoreHeaderViewController : UIViewController
- (void)entityHeaderViewController:(id)controller didUpdateVisibleRect:(CGRect)rect;
@end
@implementation SPTFreeTierPlaylistEncoreHeaderViewController
// Spotify's own is what reports a scroll to the header; here it only gives the hook something to run after.
- (void)entityHeaderViewController:(id)controller didUpdateVisibleRect:(CGRect)rect {}
@end

@interface _TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout : UIView @end
@implementation _TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout @end

@interface _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView : UIView @end
@implementation _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView @end

@interface _TtC19LegacyUI_ECMCoreKit13GradientView : UIView @end
@implementation _TtC19LegacyUI_ECMCoreKit13GradientView @end

@interface _TtC44PlaylistCuration_ExpandableTextElementKit18ExpandableTextView : UITextView @end
@implementation _TtC44PlaylistCuration_ExpandableTextElementKit18ExpandableTextView @end

@interface _TtCE13Encore_FaceKitO16EncoreFoundation6Encore12FacepileView : UIView @end
@implementation _TtCE13Encore_FaceKitO16EncoreFoundation6Encore12FacepileView @end

@interface _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView : UIView @end
@implementation _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView @end

@interface _TtC35ListUXPlatform_FreeTierPlaylistImpl25ElementCollectionViewCell : UICollectionViewCell @end
@implementation _TtC35ListUXPlatform_FreeTierPlaylistImpl25ElementCollectionViewCell @end

@interface _TtGC13Element_UIKit11ElementViewT_P_P__ : UIView @end
@implementation _TtGC13Element_UIKit11ElementViewT_P_P__ @end

// The plain UIView Liked Songs' shuffle stack sits in: its own pass puts the stack back where Spotify's
// constraints want it, on the right of the row, which is what made the shuffle flash there on the phone.
@interface MockRightHost : UIView @end
@implementation MockRightHost
- (void)layoutSubviews {
    [super layoutSubviews];
    self.subviews.firstObject.frame = CGRectMake(52, 0, 48, 48);
}
@end

@interface MockCondensedButton : UIControl @end
@implementation MockCondensedButton @end

#pragma mark - building the tree

static UIView *box(UIView *parent, Class cls, CGRect frame, NSString *identifier) {
    UIView *view = [[cls alloc] initWithFrame:frame];
    view.accessibilityIdentifier = identifier;
    [parent addSubview:view];
    return view;
}

static UILabel *label(UIView *parent, CGRect frame, NSString *text, CGFloat size, UIColor *color, NSString *identifier) {
    UIView *encore = box(parent, UIView.class, frame, identifier);
    UILabel *inner = [[UILabel alloc] initWithFrame:encore.bounds];
    inner.text = text;
    inner.font = [UIFont systemFontOfSize:size];
    inner.textColor = color;
    inner.accessibilityIdentifier = [identifier stringByAppendingString:@"-internal"];
    [encore addSubview:inner];
    return inner;
}

static UIImage *artwork(void) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(300, 300)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {0.93, 0.30, 0.47, 1, 0.28, 0.12, 0.42, 1};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, NULL, 2);
        CGContextDrawLinearGradient(c, gradient, CGPointZero, CGPointMake(300, 300), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        [[UIColor colorWithWhite:1 alpha:0.35] setFill];
        for (int i = 0; i < 5; i++) {
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(30 + i * 50, 40 + (i % 3) * 60, 70, 70)] fill];
        }
    }];
}

static UIImage *playGlyph(void) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(48, 48)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(19, 15)];
        [path addLineToPoint:CGPointMake(33, 24)];
        [path addLineToPoint:CGPointMake(19, 33)];
        [path closePath];
        [UIColor.blackColor setFill];
        [path fill];
    }];
}

static UIView *actionButton(UIView *row, CGRect frame, NSString *identifier, NSString *a11y) {
    UIView *action = box(row, UIView.class, frame, nil);
    UIView *element = box(action, UIView.class, action.bounds, nil);
    UIView *button = box(element, UIButton.class, element.bounds, identifier);
    button.accessibilityLabel = a11y;
    UIImageView *glyph = [[UIImageView alloc] initWithFrame:CGRectInset(button.bounds, 12, 12)];
    NSDictionary *glyphs = @{@"Components.UI.AddToButton": @"plus", @"Components.UI.ContextMenuButton": @"ellipsis",
                             @"DownloadButton.Granular.None": @"arrow.down.circle", @"Components.UI.WatchFeedEntityExplorerButton": @"play.rectangle"};
    glyph.image = [UIImage systemImageNamed:glyphs[identifier] ?: @"circle"];
    glyph.tintColor = UIColor.whiteColor;
    [button addSubview:glyph];
    return action;
}


// Liked Songs (trees/continuous/1.txt, 2026-09-18): the same page with no cover, a 238pt header, a column of
// only the title and the count (the count in a stack of its own, 314pt of label and a 56pt spacer), no add or
// more in the row, the play button 80x48 with its 48pt disc at x=16, and LiquidGlass.gradientContainer, the
// scrim Spotify fades in as the page scrolls. `liked` on the launch line builds it; at 3 s it is scrolled.
static void buildLikedSongs(UIViewController *page, CGFloat W) {
    UIViewController *headerVC = [SPTFreeTierPlaylistEncoreHeaderViewController new];
    [page addChildViewController:headerVC];
    UIView *header = headerVC.view;
    header.frame = CGRectMake(0, -72, W, 310);
    header.accessibilityIdentifier = @"PL.Header";
    header.backgroundColor = UIColor.clearColor;
    [page.view addSubview:header];
    [headerVC didMoveToParentViewController:page];

    UIView *headerLayout = box(header, UIView.class, CGRectMake(0, 72, W, 238), nil);
    UIView *clipping = box(headerLayout, UIView.class, headerLayout.bounds, @"_clippingView");
    UIView *background = box(clipping, UIView.class, clipping.bounds, @"_backgroundViewContainer");
    UIView *wash = box(background, UIView.class, background.bounds, nil);
    UIView *gradient = box(wash, _TtC19LegacyUI_ECMCoreKit13GradientView.class, wash.bounds, nil);
    gradient.backgroundColor = [UIColor colorWithRed:0.25 green:0.2 blue:0.7 alpha:1];
    UIView *safeArea = box(clipping, UIView.class, clipping.bounds, @"_safeAreaView");
    UIView *contentContainer = box(safeArea, UIView.class, CGRectMake(0, -72, W, 310), @"_headerContentContainer");
    UIView *contentView = box(contentContainer, UIView.class, CGRectMake(0, 72, W, 238), @"_contentViewContainer");
    UIView *layout = box(contentView, _TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout.class, contentView.bounds, nil);

    UIView *slot = box(layout, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class, CGRectMake(178.33, 68, 45.33, 45.33), nil);
    box(slot, UIView.class, slot.bounds, nil);

    UIView *block = box(layout, UIView.class, CGRectMake(0, 129.33, 386, 108.67), nil);
    UIView *blockInner = box(box(block, UIView.class, block.bounds, nil), UIView.class, CGRectMake(0, 0, 386, 100.67), nil);
    UIView *columnStack = box(blockInner, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class, CGRectMake(16, 0, 370, 100.67), nil);
    UIView *columnAndRow = box(columnStack, UIView.class, columnStack.bounds, nil);
    UIView *columnHost = box(columnAndRow, UIView.class, CGRectMake(0, 0, 370, 44.67), nil);
    UIView *titleStack = box(columnHost, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class, columnHost.bounds, nil);
    UIView *column = box(titleStack, UIView.class, titleStack.bounds, nil);
    label(column, CGRectMake(0, 0, 370, 25.33), @"Liked Songs", 21, UIColor.whiteColor, @"Encore.Label");
    UIView *countStack = box(column, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class, CGRectMake(0, 29.33, 370, 15.33), nil);
    UIView *countRow = box(countStack, UIView.class, countStack.bounds, nil);
    label(countRow, CGRectMake(0, 0, 314, 15.33), @"1 016 songs", 11, [UIColor colorWithWhite:1 alpha:0.4],
          @"Components.Header.UI.Metadata").textAlignment = NSTextAlignmentLeft;
    box(countRow, UIView.class, CGRectMake(314, 7.67, 56, 0), nil);

    UIView *rowHost = box(columnAndRow, UIView.class, CGRectMake(0, 52.67, 370, 48), nil);
    UIView *rowStack = box(rowHost, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class, rowHost.bounds, nil);
    UIView *container = box(rowStack, UIView.class, rowStack.bounds, nil);
    UIView *left = box(container, UIView.class, CGRectMake(0, 0, 96, 48), nil);
    UIView *leftStack = box(left, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class, CGRectMake(-10, 0, 106, 48), nil);
    UIView *element = box(box(leftStack, UIView.class, leftStack.bounds, nil), _TtGC13Element_UIKit11ElementViewT_P_P__.class, CGRectMake(0, 0, 106, 48), nil);
    UIStackView *actions = (UIStackView *)box(element, UIStackView.class, element.bounds, @"HeaderActionsRow");
    actionButton(actions, CGRectMake(0, 4, 58, 40), @"Components.UI.WatchFeedEntityExplorerButton", @"Explore Liked Songs");
    actionButton(actions, CGRectMake(58, 0, 48, 48), @"DownloadButton.Granular.None", @"Download");
    box(container, UIView.class, CGRectMake(96, 23.67, 174, 1), nil);
    UIView *right = box(container, MockRightHost.class, CGRectMake(270, 0, 100, 48), nil);
    UIView *rightStack = box(right, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class, CGRectMake(-184, 0, 48, 48), nil);
    UIView *shuffleHost = box(box(rightStack, UIView.class, rightStack.bounds, nil), UIView.class, CGRectMake(0, 0, 48, 48), nil);
    UIView *shuffle = box(shuffleHost, UIButton.class, shuffleHost.bounds, @"Components.UI.ShuffleButton");
    shuffle.accessibilityLabel = @"Shuffle tracks";
    UIImageView *shuffleGlyph = [[UIImageView alloc] initWithFrame:CGRectInset(shuffle.bounds, 12, 12)];
    shuffleGlyph.image = [UIImage systemImageNamed:@"shuffle"];
    shuffleGlyph.tintColor = [UIColor colorWithRed:0.02 green:0.97 blue:0 alpha:1];
    [shuffle addSubview:shuffleGlyph];

    UIView *scrim = box(headerLayout, UIView.class, CGRectMake(0, 0, W, 124), @"LiquidGlass.gradientContainer");
    scrim.alpha = 0;
    box(scrim, UIView.class, scrim.bounds, @"LiquidGlass.GradientView").backgroundColor = [UIColor colorWithRed:0.25 green:0.3 blue:0.9 alpha:1];

    UIView *foreground = box(headerLayout, UIView.class, headerLayout.bounds, @"_foregroundViewContainer");
    UIView *playButton = box(foreground, _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView.class, CGRectMake(322, 182, 80, 48), @"header-play-button");
    UIControl *condensed = (UIControl *)box(playButton, MockCondensedButton.class, CGRectMake(16, 0, 48, 48), nil);
    condensed.accessibilityLabel = @"Shuffle Play";
    UIImageView *disc = [[UIImageView alloc] initWithFrame:condensed.bounds];
    disc.image = [[UIImage systemImageNamed:@"shuffle"] imageByApplyingSymbolConfiguration:
                  [UIImageSymbolConfiguration configurationWithPointSize:18]];
    disc.contentMode = UIViewContentModeCenter;
    disc.backgroundColor = [UIColor colorWithRed:0.02 green:0.97 blue:0 alpha:1];
    [condensed addSubview:disc];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        scrim.alpha = 1;
        [layout setNeedsLayout];
        [layout layoutIfNeeded];
        // Spotify's parent laying the shuffle out again, after every pass of the header's.
        [right setNeedsLayout];
        [right layoutIfNeeded];
        CGRect shuffleInRow = [container convertRect:shuffle.bounds fromView:shuffle];
        UIView *capsule = container.subviews.lastObject;
        NSLog(@"[harness] liked: after the shuffle's parent laid out: shuffle %@, capsule %@ (%@), screen middle %.1f",
              NSStringFromCGRect([container convertRect:shuffleInRow toView:nil]),
              NSStringFromCGRect([container convertRect:capsule.frame toView:nil]), capsule.class,
              CGRectGetMidX(page.view.bounds));
        NSLog(@"[harness] liked: scrolled, scrim a=%.2f hidden=%d masked=%d; column rows %@ / %@",
              scrim.alpha, scrim.layer.hidden, scrim.layer.mask != nil,
              NSStringFromCGRect(column.subviews[0].frame), NSStringFromCGRect(column.subviews[1].frame));
    });
}

@interface SGRHarnessDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SGRHarnessDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    CGFloat W = self.window.bounds.size.width, H = self.window.bounds.size.height;

    UIViewController *page = [_TtC35ListUXPlatform_FreeTierPlaylistImpl17FTPViewController new];
    page.view.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    self.window.rootViewController = page;

    // the list
    UIScrollView *list = (UIScrollView *)box(page.view, _TtC35ListUXPlatform_FreeTierPlaylistImpl32FTPTouchCancellingCollectionView.class,
                                             CGRectMake(0, 0, W, H), @"SPTFreeTierPlaylistTableView");
    list.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    NSArray<NSArray<NSString *> *> *tracks = @[@[@"Cry For Me", @"The Weeknd"], @[@"I Can't Fucking Sing", @"The Weeknd"],
                                              @[@"São Paulo", @"The Weeknd, Anitta"], @[@"Until We're Skin & Bones", @"The Weeknd"],
                                              @[@"Baptized In Fear", @"The Weeknd"]];
    for (NSUInteger i = 0; i < tracks.count; i++) {
        UIView *cell = box(list, _TtC35ListUXPlatform_FreeTierPlaylistImpl25ElementCollectionViewCell.class,
                           CGRectMake(0, 512 + i * 64, W, 64), @"Playlist.ItemCell");
        cell.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
        UIView *row = box(cell, UIView.class, cell.bounds, @"Encore.ListRow");
        row.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
        UIView *art = box(row, UIView.class, CGRectMake(16, 8, 48, 48), @"Encore.ImageView");
        UIImageView *picture = [[UIImageView alloc] initWithFrame:art.bounds];
        picture.image = artwork();
        [art addSubview:picture];
        label(row, CGRectMake(76, 12, W - 130, 20), tracks[i][0], 16, UIColor.whiteColor, @"Track.Row.Content.Title");
        label(row, CGRectMake(76, 32, W - 130, 18), tracks[i][1], 14, [UIColor colorWithWhite:1 alpha:0.7], @"Track.Row.Content.Subtitle");
    }

    if ([NSProcessInfo.processInfo.arguments containsObject:@"liked"]) {
        buildLikedSongs(page, W);
        [self.window makeKeyAndVisible];
        return YES;
    }

    // the header
    UIViewController *headerVC = [SPTFreeTierPlaylistEncoreHeaderViewController new];
    [page addChildViewController:headerVC];
    UIView *header = headerVC.view;
    header.frame = CGRectMake(0, -134, W, 639.33);
    header.accessibilityIdentifier = @"PL.Header";
    header.backgroundColor = UIColor.clearColor;
    [page.view addSubview:header];
    [headerVC didMoveToParentViewController:page];

    UIView *headerLayout = box(header, UIView.class, CGRectMake(0, 134, W, 505.33), nil);
    UIView *clipping = box(headerLayout, UIView.class, headerLayout.bounds, @"_clippingView");
    UIView *background = box(clipping, UIView.class, clipping.bounds, @"_backgroundViewContainer");
    UIView *wash = box(background, UIView.class, background.bounds, nil);
    wash.clipsToBounds = YES;
    UIView *gradient = box(wash, _TtC19LegacyUI_ECMCoreKit13GradientView.class, wash.bounds, nil);
    gradient.backgroundColor = [UIColor colorWithRed:0.5 green:0.1 blue:0.3 alpha:1];

    UIView *safeArea = box(clipping, UIView.class, clipping.bounds, @"_safeAreaView");
    UIView *contentContainer = box(safeArea, UIView.class, CGRectMake(0, -134, W, 639.33), @"_headerContentContainer");
    UIView *contentView = box(contentContainer, UIView.class, CGRectMake(0, 134, W, 505.33), @"_contentViewContainer");
    UIView *layout = box(contentView, _TtC28EncoreConsumerMobile_BaseKit19HeaderContentLayout.class, contentView.bounds, nil);

    // the cover square
    UIView *cover = box(layout, UIView.class, CGRectMake(round((W - 182) / 2), 68, 182, 182), @"Components.Header.UI.ArtworkImage");
    UIView *coverImage = box(cover, UIView.class, cover.bounds, @"Encore.ImageView");
    UIImageView *coverPicture = [[UIImageView alloc] initWithFrame:coverImage.bounds];
    coverPicture.image = artwork();
    coverPicture.contentMode = UIViewContentModeScaleAspectFill;
    [coverImage addSubview:coverPicture];

    // the block: the column, then the action row
    UIView *block = box(layout, UIView.class, CGRectMake(0, 266.67, W - 16, 178.33), nil);
    UIView *blockStack = box(block, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class, block.bounds, nil);
    UIView *blockInner = box(blockStack, UIView.class, blockStack.bounds, nil);

    UIView *columnHost = box(blockInner, UIView.class, CGRectMake(0, 0, block.bounds.size.width, 122.33), nil);
    UIView *columnStack = box(columnHost, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class,
                              CGRectMake(16, 0, columnHost.bounds.size.width - 16, 122.33), nil);
    UIView *column = box(columnStack, UIView.class, columnStack.bounds, nil);
    CGFloat columnWidth = column.bounds.size.width;

    label(column, CGRectMake(0, 0, columnWidth, 29.67), @"Hurry Up Tomorrow", 21, UIColor.whiteColor, @"Encore.Label");

    UIView *descriptionRow = box(column, UIView.class, CGRectMake(0, 33.67, columnWidth, 31.33), nil);
    UITextView *description = (UITextView *)box(descriptionRow, _TtC44PlaylistCuration_ExpandableTextElementKit18ExpandableTextView.class,
                                                descriptionRow.bounds, nil);
    description.text = @"On what was meant to be the last date of his 2022 tour, The Weeknd took the stage.";
    description.font = [UIFont systemFontOfSize:14];
    description.textColor = UIColor.whiteColor;
    description.backgroundColor = UIColor.clearColor;
    description.textContainerInset = UIEdgeInsetsZero;
    description.textContainer.lineFragmentPadding = 0;

    UIView *creatorRow = box(column, UIView.class, CGRectMake(0, 69, columnWidth, 34), nil);
    UIView *creator = box(creatorRow, UIView.class, CGRectMake(0, 0, 109.67, 34), nil);
    UIView *face = box(creator, _TtCE13Encore_FaceKitO16EncoreFoundation6Encore12FacepileView.class, CGRectMake(0, 5, 24, 24), nil);
    face.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    face.layer.cornerRadius = 12;
    label(creator, CGRectMake(32, 9, 77, 16), @"The Weeknd", 13, UIColor.whiteColor, @"Encore.Label");
    box(creatorRow, UIView.class, CGRectMake(109.67, 0, columnWidth - 109.67, 34), nil);

    UIView *lengthRow = box(column, UIView.class, CGRectMake(0, 107, columnWidth, 15.33), nil);
    UIView *length = box(lengthRow, UIView.class, CGRectMake(0, 0, 126.33, 15.33), nil);
    label(length, CGRectMake(0, 0, 126.33, 15.33), @"4 637 saves • 20h 28m", 11, [UIColor colorWithWhite:1 alpha:0.7],
          @"Components.Header.UI.Metadata");
    box(lengthRow, UIView.class, CGRectMake(126.33, 0, columnWidth - 126.33, 15.33), nil);

    UIView *actionHost = box(blockInner, UIView.class, CGRectMake(0, 130.33, block.bounds.size.width, 48), nil);
    UIView *actionStack = box(actionHost, _TtC19LegacyUI_ECMCoreKit19AutoLayoutStackView.class,
                              CGRectMake(4, 0, actionHost.bounds.size.width - 4, 48), nil);
    UIView *container = box(actionStack, UIView.class, actionStack.bounds, nil);
    UIView *rowElement = box(container, _TtGC13Element_UIKit11ElementViewT_P_P__.class, CGRectMake(0, 0, 198, 48), nil);
    UIStackView *actions = (UIStackView *)box(rowElement, UIStackView.class, rowElement.bounds, @"HeaderActionsRow");
    actionButton(actions, CGRectMake(0, 4, 58, 40), @"Components.UI.WatchFeedEntityExplorerButton", @"Explore");
    actionButton(actions, CGRectMake(58, 0, 48, 48), @"Components.UI.AddToButton", @"Like");
    actionButton(actions, CGRectMake(106, 0, 48, 48), @"DownloadButton.Granular.None", @"Download");
    actionButton(actions, CGRectMake(154, 2, 44, 44), @"Components.UI.ContextMenuButton", @"More options");

    UIView *mixShuffle = box(container, UIView.class, CGRectMake(container.bounds.size.width - 124, 0, 124, 48), nil);
    UIView *mixShuffleStack = box(mixShuffle, UIStackView.class, CGRectMake(0, 0, 68, 48), nil);
    box(mixShuffleStack, UIView.class, CGRectMake(0, 0, 20, 48), @"MixAndShuffleComposedUI.mixView");
    UIView *shuffleView = box(mixShuffleStack, UIView.class, CGRectMake(20, 0, 48, 48), @"MixAndShuffleComposedUI.shuffleView");
    UIView *shuffleElement = box(shuffleView, UIView.class, shuffleView.bounds, nil);
    UIView *shuffle = box(shuffleElement, UIButton.class, shuffleElement.bounds, @"Components.UI.ShuffleButton");
    shuffle.accessibilityLabel = @"Shuffle tracks";
    UIImageView *shuffleGlyph = [[UIImageView alloc] initWithFrame:CGRectInset(shuffle.bounds, 12, 12)];
    shuffleGlyph.image = [UIImage systemImageNamed:@"shuffle"];
    shuffleGlyph.tintColor = UIColor.whiteColor;
    [shuffle addSubview:shuffleGlyph];

    // the play button, in the header's foreground plane
    UIView *foreground = box(headerLayout, UIView.class, headerLayout.bounds, @"_foregroundViewContainer");
    UIView *playHost = box(foreground, UIView.class, CGRectMake(W - 64, 457.33, 64, 48), nil);
    UIView *playButton = box(playHost, _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView.class, CGRectMake(0, 0, 48, 48), @"header-play-button");
    UIControl *condensed = (UIControl *)box(playButton, MockCondensedButton.class, playButton.bounds, nil);
    condensed.accessibilityLabel = @"Play";
    UIImageView *disc = [[UIImageView alloc] initWithFrame:condensed.bounds];
    disc.image = playGlyph();
    disc.backgroundColor = [UIColor colorWithRed:0.12 green:0.84 blue:0.38 alpha:1];
    disc.layer.cornerRadius = 24;
    disc.clipsToBounds = YES;
    [condensed addSubview:disc];

    [self.window makeKeyAndVisible];

    // The header collapsing, and the page pulled down past the top, with the frames Spotify sets in each
    // (trees/continuous/2.txt and 4.txt). The hero has to slide up out of the clipping view with the plane
    // the wash is on, not be resized into a strip at the top of the screen.
    void (^setState)(NSString *) = ^(NSString *state) {
        BOOL collapsed = [state isEqualToString:@"collapsed"];
        BOOL pulled = [state isEqualToString:@"pulled"];
        CGFloat layoutHeight = collapsed ? 110 : (pulled ? 608 : 474);
        header.frame = CGRectMake(0, collapsed ? -498 : (pulled ? 0 : -134), W, 608);
        headerLayout.frame = CGRectMake(0, collapsed ? 498 : (pulled ? 0 : 134), W, layoutHeight);
        clipping.frame = CGRectMake(0, 0, W, layoutHeight);
        background.frame = CGRectMake(0, 0, W, layoutHeight);
        background.alpha = collapsed ? 0 : 1;
        wash.frame = collapsed ? CGRectMake(0, -364, W, 474) : CGRectMake(0, 0, W, layoutHeight);
        safeArea.frame = CGRectMake(0, 0, W, layoutHeight);
        contentContainer.frame = CGRectMake(0, pulled ? 0 : -134, W, collapsed ? 244 : 608);
        contentView.frame = CGRectMake(0, 134, W, collapsed ? 110 : 474);
        layout.frame = CGRectMake(0, 0, W, collapsed ? 110 : 474);
        cover.frame = collapsed ? CGRectMake(148.67, 68, 104.67, 104.67) : CGRectMake(round((W - 243) / 2), 68, 243, 243);
        block.frame = collapsed ? CGRectMake(0, -26.33, W - 16, 136.33) : CGRectMake(0, 327, W - 16, 178.33);
        [layout setNeedsLayout];
        [layout layoutIfNeeded];
        UIView *hero = wash.subviews.firstObject;
        NSLog(@"[harness] state %@: hero %@ in the plane, %@ in the window", state,
              NSStringFromCGRect(hero.frame), NSStringFromCGRect([wash convertRect:hero.frame toView:nil]));
    };
    for (NSUInteger i = 0; i < 3; i++) {
        NSString *state = @[@"rest", @"collapsed", @"pulled"][i];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((4 + i * 4) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            setState(state);
        });
    }

    // Spotify fading its cover square and its colour wash back in as the header opens, which it does on the
    // scroll itself with nothing laid out: only the hook on that scroll sees it.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(16 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setState(@"rest");
        cover.alpha = 1;
        gradient.alpha = 1;
        NSLog(@"[harness] Spotify's cover and wash faded back in");
        [(SPTFreeTierPlaylistEncoreHeaderViewController *)headerVC entityHeaderViewController:nil didUpdateVisibleRect:CGRectZero];
        NSLog(@"[harness] after Spotify's fade back in: cover a=%.2f layer.hidden=%d, wash a=%.2f layer.hidden=%d",
              cover.alpha, cover.layer.hidden, gradient.alpha, gradient.layer.hidden);
    });

    // Spotify lays the column and the action row out again after the header's pass: their children go back
    // where its own layout put them, and the redesign has to take them again from its own watch on each.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSArray<NSValue *> *columnFrames = @[[NSValue valueWithCGRect:CGRectMake(0, 0, columnWidth, 29.67)],
                                             [NSValue valueWithCGRect:CGRectMake(0, 33.67, columnWidth, 31.33)],
                                             [NSValue valueWithCGRect:CGRectMake(0, 69, columnWidth, 34)],
                                             [NSValue valueWithCGRect:CGRectMake(0, 107, columnWidth, 15.33)]];
        for (NSUInteger i = 0; i < columnFrames.count && i < column.subviews.count; i++) {
            column.subviews[i].frame = columnFrames[i].CGRectValue;
        }
        shuffleView.frame = CGRectMake(20, 0, 48, 48);
        for (NSUInteger i = 0; i < actions.subviews.count; i++) {
            actions.subviews[i].frame = CGRectMake(i * 48, i == 0 ? 4 : 0, i == 0 ? 58 : 48, i == 0 ? 40 : 48);
        }
        [column setNeedsLayout];
        [actions setNeedsLayout];
        NSLog(@"[harness] Spotify's own frames put back");
    });

    // Pressing Play: Spotify reconfigures the header and shows the wash and the play disc again with
    // -setHidden:NO (trees/continuous/1.txt, 2026-09-18). They must stay drawn by nothing.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(17 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gradient.hidden = NO;
        playButton.hidden = NO;
        cover.hidden = NO;
        NSLog(@"[harness] Pressing Play: wash hidden=%d masked=%d, disc hidden=%d masked=%d, cover hidden=%d masked=%d",
              gradient.hidden, gradient.layer.mask != nil, playButton.hidden, playButton.layer.mask != nil,
              cover.hidden, cover.layer.mask != nil);
    });
    return YES;
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
