#import "SGModPage.h"
#import "SGPageStyle.h"
#import "Core/SGCore.h"
#import "Features/Flags/Flags.h"
#import "Features/About/About.h"
#import "Features/AdBlock/AdBlock.h"

NSString *const SGRestartNote = @"Changes apply after you restart Spotify.";

@implementation SGModRow
@end

@implementation SGModSection
@end

SGModRow *SGSwitchRow(NSString *title, NSString *subtitle, NSString *key) {
    SGModRow *row = [SGModRow new];
    row.title = title;
    row.subtitle = subtitle;
    row.key = key;
    row.defaultOn = YES;
    return row;
}

SGModRow *SGHideRow(NSString *title, NSString *subtitle, NSString *key) {
    SGModRow *row = SGSwitchRow(title, subtitle, key);
    row.defaultOn = NO;
    return row;
}

// A switch for something the mod adds rather than takes away: off until it is asked for.
SGModRow *SGOptionRow(NSString *title, NSString *subtitle, NSString *key) {
    SGModRow *row = SGSwitchRow(title, subtitle, key);
    row.defaultOn = NO;
    return row;
}

// A switch whose work is not finished: turning it on says so first, and offers the repo to anyone
// who would rather fix it than live with it.
SGModRow *SGUnstableRow(NSString *title, NSString *subtitle, NSString *key, NSString *warning) {
    SGModRow *row = SGSwitchRow(title, subtitle, key);
    row.warning = warning;
    return row;
}

SGModRow *SGFlagRow(NSString *title, NSString *key) {
    SGModRow *row = SGHideRow(title, [key substringFromIndex:[key rangeOfString:@"."].location + 1], key);
    row.flag = YES;
    return row;
}

// A flag Spotify ships on: the switch forces it off.
SGModRow *SGKillRow(NSString *title, NSString *key) {
    SGModRow *row = SGFlagRow(title, key);
    row.forceOff = YES;
    return row;
}

SGModRow *SGStatRow(NSString *title, NSString *(^value)(void)) {
    SGModRow *row = [SGModRow new];
    row.title = title;
    row.value = value;
    return row;
}

SGModRow *SGActionRow(NSString *title, NSString *subtitle, void (^action)(void)) {
    SGModRow *row = [SGModRow new];
    row.title = title;
    row.subtitle = subtitle;
    row.action = action;
    return row;
}

// Red, with a warning symbol. SGFillCell tints the title and the symbol; the cell below takes the
// colour down to the subtitle too, so the whole row reads as the warning it is.
SGModRow *SGWarningRow(NSString *title, NSString *subtitle, void (^action)(void)) {
    SGModRow *row = SGActionRow(title, subtitle, action);
    row.color = SGRed();
    row.symbol = @"exclamationmark.triangle.fill";
    return row;
}

// No subtitle: a list of pages reads as a list, not as a wall of explanations.
SGModRow *SGPageRow(NSString *title, UIViewController *(^page)(void)) {
    SGModRow *row = [SGModRow new];
    row.title = title;
    row.page = page;
    return row;
}

// The list a choice row opens: the names it was given, a green checkmark against the one set.
// Picking one writes the index and goes back, where the row it came from reads the new name out
// and the page it sits on rebuilds around it.
@interface SGChoicePage : SGPage
- (instancetype)initWithTitle:(NSString *)title key:(NSString *)key choices:(NSArray<NSString *> *)choices fallback:(NSInteger)fallback;
@end

@implementation SGChoicePage {
    NSString *_key;
    NSArray<NSString *> *_choices;
    NSInteger _fallback;
}

- (instancetype)initWithTitle:(NSString *)title key:(NSString *)key choices:(NSArray<NSString *> *)choices fallback:(NSInteger)fallback {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = title;
    _key = key;
    _choices = choices;
    _fallback = fallback;
    return self;
}


- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    SGInsetForBars(self.tableView);
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_choices.count;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = SGDequeueCell(table, @"choice");
    SGFillCell(cell, _choices[(NSUInteger)path.row], nil, nil, nil);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (path.row == SGInt(_key, _fallback)) {
        UIImageView *tick = SGSymbolView(@"checkmark", 13, UIImageSymbolWeightSemibold, 16);
        tick.tintColor = SGGreen();
        cell.accessoryView = tick;
    }
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:NO];
    SGSetInt(_key, path.row);
    [table reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}

@end

// No key on the row: the key lives in the blocks, so the page draws the row as the link it is
// rather than as a switch.
SGModRow *SGChoiceRow(NSString *title, NSString *subtitle, NSString *key, NSArray<NSString *> *choices, NSInteger fallback) {
    SGModRow *row = [SGModRow new];
    row.title = title;
    row.subtitle = subtitle;
    row.value = ^NSString *{
        NSInteger index = SGInt(key, fallback);
        return index >= 0 && index < (NSInteger)choices.count ? choices[(NSUInteger)index] : choices.firstObject;
    };
    row.page = ^UIViewController *{
        return [[SGChoicePage alloc] initWithTitle:title key:key choices:choices fallback:fallback];
    };
    return row;
}

SGModRow *SGLinkRow(NSString *title, NSString *subtitle, NSString *url) {
    return SGActionRow(title, subtitle, ^{ SGOpenURL(url); });
}

// A value on the right and a tap: the Updates row reads its status out of About/Update.m every tick,
// and a tap asks the site again instead of waiting for the six hour cache to lapse.
SGModRow *SGStatActionRow(NSString *title, NSString *subtitle, NSString *(^value)(void), void (^action)(void)) {
    SGModRow *row = [SGModRow new];
    row.title = title;
    row.subtitle = subtitle;
    row.value = value;
    row.action = action;
    return row;
}

SGModSection *SGSection(NSString *title, NSArray<SGModRow *> *rows) {
    SGModSection *s = [SGModSection new];
    s.title = title;
    s.rows = rows;
    return s;
}

// What a page row carrying a value shows on the right: the value, then the chevron, the same
// distance apart as Spotify's own rows keep them.
static UIView *valueAndChevron(NSString *text) {
    UILabel *label = [UILabel new];
    label.font = SGTitleFont();
    label.textColor = SGGrey();
    label.text = text;
    [label sizeToFit];
    UIImageView *chevron = SGSymbolView(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
    CGFloat height = MAX(label.bounds.size.height, chevron.bounds.size.height);
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, label.bounds.size.width + 6 + chevron.bounds.size.width, height)];
    label.center = CGPointMake(label.bounds.size.width / 2, height / 2);
    chevron.center = CGPointMake(box.bounds.size.width - chevron.bounds.size.width / 2, height / 2);
    [box addSubview:label];
    [box addSubview:chevron];
    return box;
}

// On means the row's own override is in place; anything else, including the opposite override
// somebody set from the All flags page, reads as off.
static BOOL flagRowOn(SGModRow *row) {
    id value = SGFlagOverride(row.key);
    return value && [value boolValue] != row.forceOff;
}

// A flag the Liquid Glass UI switch owns: its row shows what that switch forces and
// takes no touch, so the flag has one place to change. An override from All flags still wins.
static BOOL flagRowLocked(SGModRow *row) {
    if (!row.flag) return NO;
    return (SGGlassOwnsFlag(row.key) && SGFlag(SGKeySpotifyGlass, NO)) || (row.forceOff && SGAdBlockForcesFlagOff(row.key));
}

@implementation SGModPage {
    NSArray<SGModSection *> *_sections;
    UIView *_intro;
    UIView *_footer;
    NSTimer *_ticker;
    BOOL _live;
}

- (instancetype)initWithTitle:(NSString *)title intro:(NSString *)intro sections:(NSArray<SGModSection *> *)sections footer:(NSString *)footer {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = title;
    _sections = sections;
    _intro = intro ? SGNote(intro) : nil;
    _footer = footer ? SGNote(footer) : nil;
    // A page row reads its value out when the page appears rather than on the ticker, so only the
    // rows whose numbers climb on their own keep one running.
    for (SGModSection *s in sections) for (SGModRow *row in s.rows) _live |= row.value && !row.page;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableHeaderView = _intro;
    self.tableView.tableFooterView = _footer;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (_intro) SGFitNote(self.tableView, _intro, 24, 0);
    if (_footer) SGFitNote(self.tableView, _footer, 16, 24);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    SGInsetForBars(self.tableView);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Reloaded whether or not anything ticks: a choice row is showing whatever was picked on the
    // page it opened, which is gone by the time this one comes back.
    [self.tableView reloadData];
    if (!_live) return;
    // The counters climb while the page is open; the labels are written straight into the cells so
    // that a reload never lands under a switch being dragged.
    _ticker = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(readValues) userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_ticker invalidate];
    _ticker = nil;
}

- (void)readValues {
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        SGModRow *row = [self rowAt:[self.tableView indexPathForCell:cell]];
        UILabel *label = (UILabel *)cell.accessoryView;
        if (!row.value || row.page || ![label isKindOfClass:UILabel.class]) continue;
        label.text = row.value();
        [label sizeToFit];
        [cell setNeedsLayout];
    }
}

- (SGModRow *)rowAt:(NSIndexPath *)path {
    return _sections[(NSUInteger)path.section].rows[(NSUInteger)path.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_sections[(NSUInteger)section].rows.count;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    NSString *title = _sections[(NSUInteger)section].title;
    return title ? SGSectionHeader(table, title) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return _sections[(NSUInteger)section].title ? SGSectionHeaderHeight : CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = SGDequeueCell(table, @"row");
    SGModRow *row = [self rowAt:path];
    SGFillCell(cell, row.title, row.subtitle, row.color, row.symbol);
    UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
    if (row.color) content.secondaryTextProperties.color = row.color;
    if (row.page && row.symbol) content.image = SGTileImage(row.symbol);
    cell.contentConfiguration = content;
    cell.separatorInset = UIEdgeInsetsMake(0, row.symbol ? (row.page ? 58 : 48) : 16, 0, 0);

    if (row.key) {
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = SGGreen();
        BOOL locked = flagRowLocked(row);
        toggle.on = row.flag ? (locked && !SGFlagOverride(row.key) ? YES : flagRowOn(row)) : SGFlag(row.key, row.defaultOn);
        toggle.enabled = !locked;
        // A disabled switch would swallow the tap; letting it through is what gets the row asked.
        toggle.userInteractionEnabled = !locked;
        toggle.tag = path.section * 1000 + path.row;
        [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = locked ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    } else if (row.page) {
        cell.accessoryView = row.value ? valueAndChevron(row.value()) : SGSymbolView(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else if (row.value) {
        UILabel *label = [UILabel new];
        label.font = SGTitleFont();
        label.textColor = SGGrey();
        label.text = row.value();
        [label sizeToFit];
        cell.accessoryView = label;
        cell.selectionStyle = row.action ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    } else if (row.action) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    SGModRow *row = [self rowAt:path];
    if (flagRowLocked(row)) {
        [table deselectRowAtIndexPath:path animated:YES];
        [self explainLock];
        return;
    }
    if (row.page) [self.navigationController pushViewController:row.page() animated:YES];
    if (!row.action) return;
    row.action();
    [table deselectRowAtIndexPath:path animated:YES];
    [self readValues];
}

- (void)toggled:(UISwitch *)toggle {
    SGModRow *row = [self rowAt:[NSIndexPath indexPathForRow:toggle.tag % 1000 inSection:toggle.tag / 1000]];
    if (row.flag) SGSetFlagOverride(row.key, toggle.on ? @(!row.forceOff) : nil);
    else SGSetEnabled(row.key, toggle.on);
    if (row.changed) {
        row.changed(toggle.on);
        [self.tableView reloadData];
    }
    if (toggle.on && row.warning) [self warn:row];
}

// A locked row will not move, and nothing on it says why.
- (void)explainLock {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Overridden by another setting"
                         message:@"Another switch is forcing this flag, so the row shows what it forces instead of taking a value of its own."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)warn:(SGModRow *)row {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[row.title stringByAppendingString:@" is unstable"]
                                                                  message:row.warning
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Open GitHub" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        SGOpenURL(SGRepoURL);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
