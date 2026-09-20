// Spotify's context menu sheet mocked under its class name, presented from a now playing controller,
// so PlayerMenu.x's hook adds Speed and pitch the way it would on the phone. The script opens the menu at
// 1 s, opens the block at 3 s, moves both sliders at 5 s and closes the block at 7 s; screenshot between.
//
//     THEOS=$HOME/theos ./build.sh && xcrun simctl install booted build/MenuHarness.app
//     xcrun simctl launch --console-pty booted com.vojta.menuharness [footer] [nospeed]
#import <UIKit/UIKit.h>

#pragma mark - what PlayerMenu.x calls

static double sg_speed = 1;
static float sg_pitch;
static BOOL sg_speedAllowed = YES;
UIColor *SGRAccentColor(void) { return nil; }
void SGPlayFeedback(NSInteger feedback) { NSLog(@"[harness] feedback %ld", (long)feedback); }
void SGPrepareFeedback(NSInteger feedback) {}
double SGPlayerSpeed(void) { return sg_speed; }
BOOL SGPlayerSpeedAllowed(void) { return sg_speedAllowed; }
void SGSetPlayerSpeed(double speed) { sg_speed = speed; NSLog(@"[harness] speed %.2f", speed); }
float SGPlayerPitch(void) { return sg_pitch; }
void SGSetPlayerPitch(float semitones) { sg_pitch = semitones; NSLog(@"[harness] pitch %.0f", semitones); }
BOOL SGPlayerPitchAvailable(void) { return YES; }

#pragma mark - Spotify's sheet

@interface _TtC24ContextMenu_InternalImpl25ContextMenuViewController : UIViewController <UITableViewDataSource>
@property (nonatomic, strong) UITableView *table;
@end

@implementation _TtC24ContextMenu_InternalImpl25ContextMenuViewController

- (NSArray<NSArray<NSString *> *> *)rows {
    return @[@[@"plus.circle", @"Add to playlist"], @[@"music.note.list", @"Add to queue"], @[@"person", @"Go to artist"],
             @[@"square.stack", @"Go to album"], @[@"square.and.arrow.up", @"Share"], @[@"moon", @"Sleep timer"],
             @[@"dot.radiowaves.left.and.right", @"Go to song radio"], @[@"info.circle", @"View credits"]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.backgroundColor = UIColor.clearColor;
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.rowHeight = 56;
    self.table.dataSource = self;
    [self.table registerClass:UITableViewCell.class forCellReuseIdentifier:@"row"];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"footer"]) {
        UILabel *heading = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 80)];
        heading.text = @"   Spotify's heading";
        heading.textColor = UIColor.whiteColor;
        self.table.tableHeaderView = heading;
    }
    [self.view addSubview:self.table];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row" forIndexPath:indexPath];
    UIListContentConfiguration *content = cell.defaultContentConfiguration;
    content.text = self.rows[indexPath.row][1];
    content.textProperties.color = UIColor.whiteColor;
    content.image = [UIImage systemImageNamed:self.rows[indexPath.row][0]];
    content.imageProperties.tintColor = [UIColor colorWithWhite:0.7 alpha:1];
    cell.contentConfiguration = content;
    cell.backgroundColor = UIColor.clearColor;
    return cell;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

@end

#pragma mark - the player

@interface NowPlayingHarnessViewController : UIViewController
@end

@implementation NowPlayingHarnessViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.25 green:0.1 blue:0.2 alpha:1];
}
@end

@interface SGRHarnessDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

static UIView *findBlock(UIView *root) {
    if ([NSStringFromClass(root.class) isEqualToString:@"SGSpeedPitchView"]) return root;
    for (UIView *child in root.subviews) {
        UIView *found = findBlock(child);
        if (found) return found;
    }
    return nil;
}

static NSArray<UISlider *> *sliders(UIView *root) {
    NSMutableArray *found = [NSMutableArray array];
    if ([root isKindOfClass:UISlider.class]) [found addObject:root];
    for (UIView *child in root.subviews) [found addObjectsFromArray:sliders(child)];
    return found;
}

@implementation SGRHarnessDelegate

- (void)after:(double)seconds do:(void (^)(void))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    sg_speedAllowed = ![NSProcessInfo.processInfo.arguments containsObject:@"nospeed"];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    NowPlayingHarnessViewController *player = [NowPlayingHarnessViewController new];
    self.window.rootViewController = player;
    [self.window makeKeyAndVisible];

    __block _TtC24ContextMenu_InternalImpl25ContextMenuViewController *menu;
    [self after:1 do:^{
        menu = [_TtC24ContextMenu_InternalImpl25ContextMenuViewController new];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:menu];
        navigation.navigationBarHidden = YES;
        navigation.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
        [player presentViewController:navigation animated:YES completion:nil];
    }];
    [self after:3 do:^{
        UIControl *row = (UIControl *)findBlock(menu.view).subviews.firstObject;
        NSLog(@"[harness] block %@", findBlock(menu.view));
        [row sendActionsForControlEvents:UIControlEventTouchUpInside];
    }];
    [self after:5 do:^{
        NSArray<UISlider *> *found = sliders(findBlock(menu.view));
        found[0].value = 1.27;
        [found[0] sendActionsForControlEvents:UIControlEventValueChanged];
        [found[0] sendActionsForControlEvents:UIControlEventTouchUpInside];
        found[1].value = -3.2;
        [found[1] sendActionsForControlEvents:UIControlEventValueChanged];
        [found[1] sendActionsForControlEvents:UIControlEventTouchUpInside];
    }];
    [self after:7 do:^{
        UIControl *row = (UIControl *)findBlock(menu.view).subviews.firstObject;
        [row sendActionsForControlEvents:UIControlEventTouchUpInside];
    }];
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
