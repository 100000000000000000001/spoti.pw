#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "Onboarding.h"
#import "App/About/About.h"
#import "App/Pages.h"

static const CGFloat kMargin = 24;
static const CGFloat kCardRadius = 22;

#pragma mark - glass

// A view whose glass pane follows its bounds; the panes in SGGlass.m are laid out by their hosts.
@interface SGGlassView : UIView
@property (nonatomic) CGFloat radius;
@property (nonatomic) BOOL capsule;
@end

@implementation SGGlassView
static char kPaneKey;
- (void)layoutSubviews {
    [super layoutSubviews];
    UIVisualEffectView *pane = SGGlassFor(self, &kPaneKey);
    pane.frame = self.bounds;
    SGShapeGlass(pane, self.radius, self.capsule);
}
@end

static UIButton *glassButton(NSString *title) {
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) config = [UIButtonConfiguration prominentGlassButtonConfiguration];
    else config = [UIButtonConfiguration filledButtonConfiguration];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.baseBackgroundColor = SGGreen();
    config.baseForegroundColor = UIColor.blackColor;
    config.contentInsets = NSDirectionalEdgeInsetsMake(15, 20, 15, 20);
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]}];
    UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

#pragma mark - the tour

// One page: what the mod is, where Mod Settings lives, and the one switch worth choosing now,
// Redesigned UI. Everything else has settled into the redesign's own pages, which have little to pick.
@interface SGOnboardingController : UIViewController
@end

@implementation SGOnboardingController {
    UIImageView *_hero;
    UISwitch *_redesign;
    UIButton *_primary;
}

- (instancetype)init {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    return self;
}

- (UIView *)redesignCard {
    UIImageView *icon = SGSymbolView(@"sparkles", 17, UIImageSymbolWeightSemibold, 36);
    icon.tintColor = UIColor.whiteColor;
    icon.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    icon.layer.cornerRadius = 10;
    icon.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *title = [UILabel new];
    title.text = @"Redesigned UI";
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    title.textColor = UIColor.whiteColor;
    UILabel *subtitle = [UILabel new];
    subtitle.text = @"Spotify rebuilt in Liquid Glass, Apple Music style. Off keeps Spotify's own look";
    subtitle.font = [UIFont systemFontOfSize:12];
    subtitle.textColor = SGGrey();
    subtitle.numberOfLines = 0;
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;

    // The first launch offers the redesign switched on; the tour again from the Mod page shows the
    // stored switch.
    _redesign = [UISwitch new];
    _redesign.onTintColor = SGGreen();
    _redesign.on = SGFlag(SGKeyOnboardingSeen, NO) ? SGRedesignedUIStored() : YES;
    [_redesign addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];

    UIStackView *line = [[UIStackView alloc] initWithArrangedSubviews:@[icon, text, _redesign]];
    line.alignment = UIStackViewAlignmentCenter;
    line.spacing = 14;
    line.translatesAutoresizingMaskIntoConstraints = NO;
    // The text gives way, so the subtitle wraps instead of squeezing the switch.
    [text setContentHuggingPriority:UILayoutPriorityDefaultLow - 1 forAxis:UILayoutConstraintAxisHorizontal];
    [text setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh - 1 forAxis:UILayoutConstraintAxisHorizontal];

    SGGlassView *card = [SGGlassView new];
    card.radius = kCardRadius;
    card.clipsToBounds = YES;
    card.layer.cornerRadius = kCardRadius;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:36],
        [icon.heightAnchor constraintEqualToConstant:36],
        [line.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [line.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [line.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [line.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
    ]];
    return card;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];

    SGGlassView *halo = [SGGlassView new];
    halo.capsule = YES;
    halo.translatesAutoresizingMaskIntoConstraints = NO;
    _hero = SGSymbolView(@"music.note", 34, UIImageSymbolWeightMedium, 88);
    _hero.translatesAutoresizingMaskIntoConstraints = NO;
    [halo addSubview:_hero];
    // The column stretches its children to its width; the halo keeps its square inside a strip.
    UIView *strip = [UIView new];
    [strip addSubview:halo];

    UILabel *heading = [UILabel new];
    heading.text = @"Welcome to spoti.pw.";
    heading.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    heading.textColor = UIColor.whiteColor;
    heading.numberOfLines = 0;
    UILabel *body = [UILabel new];
    body.text = @"Spotify with a Liquid Glass redesign on top. Choose the look now; everything else waits in Mod Settings: hold Home on the tab bar, or find it at the top of the side drawer behind your avatar.";
    body.font = [UIFont systemFontOfSize:15];
    body.textColor = SGGrey();
    body.numberOfLines = 0;
    UILabel *note = [UILabel new];
    note.text = @"Free and open source, at github.com/skopevoj/spoti.pw.";
    note.font = [UIFont systemFontOfSize:12];
    note.textColor = SGGrey();
    note.numberOfLines = 0;

    UIStackView *column = [[UIStackView alloc] initWithArrangedSubviews:@[strip, heading, body, [self redesignCard], note]];
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 10;
    [column setCustomSpacing:28 afterView:strip];
    [column setCustomSpacing:28 afterView:body];
    [column setCustomSpacing:14 afterView:column.arrangedSubviews[3]];
    column.translatesAutoresizingMaskIntoConstraints = NO;

    UIScrollView *scroll = [UIScrollView new];
    scroll.alwaysBounceVertical = YES;
    scroll.showsVerticalScrollIndicator = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:column];
    [self.view addSubview:scroll];

    _primary = glassButton(@"Start listening");
    [_primary addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_primary];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    UILayoutGuide *frame = scroll.frameLayoutGuide, *content = scroll.contentLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:_primary.topAnchor constant:-12],
        [column.topAnchor constraintEqualToAnchor:content.topAnchor constant:48],
        [column.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
        [column.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:kMargin],
        [column.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-kMargin],
        [column.widthAnchor constraintEqualToAnchor:frame.widthAnchor constant:-2 * kMargin],
        [halo.leadingAnchor constraintEqualToAnchor:strip.leadingAnchor],
        [halo.topAnchor constraintEqualToAnchor:strip.topAnchor],
        [halo.bottomAnchor constraintEqualToAnchor:strip.bottomAnchor],
        [halo.widthAnchor constraintEqualToConstant:88],
        [halo.heightAnchor constraintEqualToConstant:88],
        [_hero.centerXAnchor constraintEqualToAnchor:halo.centerXAnchor],
        [_hero.centerYAnchor constraintEqualToAnchor:halo.centerYAnchor],
        [_primary.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kMargin],
        [_primary.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kMargin],
        [_primary.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16],
    ]];
    [self refresh];
}

// iOS 16 has no symbol effects and skips the bounce.
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (@available(iOS 17.0, *)) [_hero addSymbolEffect:[NSClassFromString(@"NSSymbolBounceEffect") effect]];
}

// The look is picked at launch, so a switch that differs from the running one ends the tour in a restart.
- (BOOL)needsRestart {
    return _redesign.on != SGRedesignedUI();
}

- (void)refresh {
    UIButtonConfiguration *config = _primary.configuration;
    NSString *title = self.needsRestart ? @"Restart Spotify" : @"Start listening";
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]}];
    _primary.configuration = config;
}

- (void)finish {
    SGSetEnabled(SGKeyOnboardingSeen, YES);
    SGSetRedesignedUI(_redesign.on);
    if (self.needsRestart) {
        SGRestartSpotify();
        return;
    }
    [self dismissViewControllerAnimated:YES completion:^{ SGShowSigningFixIfPending(); }];
}

@end

#pragma mark - entry

static __weak SGOnboardingController *sg_tour;

BOOL SGOnboardingShowing(void) {
    return sg_tour != nil;
}

void SGShowOnboarding(void) {
    if (sg_tour) return;
    UIViewController *top = SGTopController();
    // Presenting from an alert lands nowhere; the tour waits for it to go.
    if (!top || [top isKindOfClass:UIAlertController.class]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ SGShowOnboarding(); });
        return;
    }
    SGOnboardingController *tour = [SGOnboardingController new];
    sg_tour = tour;
    [top presentViewController:tour animated:YES completion:nil];
}
