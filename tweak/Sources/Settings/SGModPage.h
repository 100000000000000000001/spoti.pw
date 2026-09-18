// A page of sections of rows, the shape of every feature's settings page.
#import "SGPage.h"

// A row is a switch when it has a key and a link to another page when it has a page. A flag row
// switches one of Spotify's remote-config flags: on forces it (off for a forceOff row, which is how
// a flag Spotify ships on is turned off), the switch off leaves Spotify's own value. A row
// with a value reads one out on the right and is asked again while the page is open; a page row
// with a value reads it out too, next to the chevron, and is asked when the page appears. A row
// with an action runs it when tapped.
@interface SGModRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *key;
@property (nonatomic) BOOL defaultOn;
@property (nonatomic) BOOL flag;
@property (nonatomic) BOOL forceOff;
@property (nonatomic, copy) UIViewController *(^page)(void);
@property (nonatomic, copy) NSString *(^value)(void);
@property (nonatomic, copy) void (^action)(void);
@property (nonatomic, copy) NSString *warning;
@property (nonatomic, copy) void (^changed)(BOOL on);   // after the switch is stored; the page reloads
@property (nonatomic, strong) UIColor *color;   // title, subtitle and symbol, for a warning row
@property (nonatomic, copy) NSString *symbol;
// A switch row that changes the whole app draws SGGlowSwitch instead of a UISwitch.
@property (nonatomic) BOOL glows;
// An ⓘ button beside the row's switch, whose tap reads this out under the row's title.
@property (nonatomic, copy) NSString *info;
@end

@interface SGModSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<SGModRow *> *rows;
@property (nonatomic, copy) NSString *footer;
@end

@interface SGModPage : SGPage
- (instancetype)initWithTitle:(NSString *)title intro:(NSString *)intro sections:(NSArray<SGModSection *> *)sections footer:(NSString *)footer;
@end

// The intro of every page whose switches the hooks read at launch.
extern NSString *const SGRestartNote;

SGModRow *SGSwitchRow(NSString *title, NSString *subtitle, NSString *key);   // on until switched off
SGModRow *SGHideRow(NSString *title, NSString *subtitle, NSString *key);     // off until switched on
// A switch for something the mod adds rather than takes away: off until it is asked for.
SGModRow *SGOptionRow(NSString *title, NSString *subtitle, NSString *key);
// A switch whose work is not finished: turning it on says so first, and offers the repo.
SGModRow *SGUnstableRow(NSString *title, NSString *subtitle, NSString *key, NSString *warning);
SGModRow *SGFlagRow(NSString *title, NSString *key);   // forces one of Spotify's flags on
SGModRow *SGKillRow(NSString *title, NSString *key);   // forces a flag Spotify ships on off
SGModRow *SGStatRow(NSString *title, NSString *(^value)(void));
SGModRow *SGActionRow(NSString *title, NSString *subtitle, void (^action)(void));
// Red, with a warning symbol: something is wrong and tapping the row says what to do about it.
SGModRow *SGWarningRow(NSString *title, NSString *subtitle, void (^action)(void));
SGModRow *SGPageRow(NSString *title, UIViewController *(^page)(void));
// A setting picked from a list of names, stored under `key` as the index into it: the row reads the
// name of the current one out and opens a list of them, a checkmark against that one.
SGModRow *SGChoiceRow(NSString *title, NSString *subtitle, NSString *key, NSArray<NSString *> *choices, NSInteger fallback);
SGModRow *SGLinkRow(NSString *title, NSString *subtitle, NSString *url);
SGModRow *SGStatActionRow(NSString *title, NSString *subtitle, NSString *(^value)(void), void (^action)(void));
SGModSection *SGSection(NSString *title, NSArray<SGModRow *> *rows);
SGModSection *SGNotedSection(NSString *title, NSArray<SGModRow *> *rows, NSString *footer);
// Gives a row its leading symbol, drawn on a tile unless the row has a colour of its own.
SGModRow *SGWithSymbol(SGModRow *row, NSString *symbol);
