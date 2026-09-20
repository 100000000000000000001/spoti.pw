// The Updates page on the simulator: SGUpdatePage() in a navigation controller, with the real check
// running against the repo's GitHub Releases. The build it claims to be is SG_VERSION, set by
// build.sh, so `0.18.0` shows a version behind the newest and `99.0.0` shows one that is current.
// `wipe` clears what an earlier run stored, so the page opens as it does on a phone that has never
// checked, and `recheck` taps Check now five seconds in.
#import <UIKit/UIKit.h>
#import "App/About/About.h"

@interface Delegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation Delegate

- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    if ([arguments containsObject:@"wipe"]) {
        for (NSString *key in @[@"spotifyglass.update.checked", @"spotifyglass.update.releases"])
            [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
    }
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UINavigationController *stack = [[UINavigationController alloc] initWithRootViewController:SGUpdatePage()];
    stack.navigationBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.window.rootViewController = stack;
    self.window.backgroundColor = UIColor.blackColor;
    [self.window makeKeyAndVisible];
    if ([arguments containsObject:@"recheck"])
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SGCheckForUpdate(YES);
        });
    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(Delegate.class));
    }
}
