// Spotify reads every remote-config flag once at startup through the configuration provider,
// keyed "component.property". While Redesigned UI is on, the flags its screens are built on come first
// (Redesign/Kit/SGRedesign.h), so an override left from Spotify's own screens cannot pull a redesigned
// one apart; then an override from the Flags page, then the flags of Spotify's own newer design, which
// it ships switched off and Redesigned UI turns on.
#import "Core/SGCore.h"
#import "Flags.h"
#import "Features/AdBlock/AdBlock.h"
#import "Features/LyricsSources/LyricsSources.h"
#import "Redesign/Kit/SGRedesign.h"

BOOL SGGlassOwnsFlag(NSString *key) {
    static NSSet<NSString *> *owned;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        owned = [NSSet setWithArray:@[
            @"ios-reprise-liquid-glass-properties.context_menu_in_navigation_bar_enabled",
            @"ios-feature-encoreexperiments.new_npv_slider_enabled",
            @"ios-feature-nowplaying.sheet_style_npv",
            @"ios-feature-nowplaying.bottom_sheet_queue_enabled",
            @"ios-feature-nowplaying.new_redesign_header_with_context_menu_enabled",
            @"ios-feature-nowplaying-elements.enable_connect_bottom_sheet",
            @"ios-playbackcontrol-audiovideoswitcher-impl.enable_connect_bottom_sheet",
            @"ios-feature-sleeptimer.use_options_sheet",
        ]];
    });
    return [owned containsObject:key];
}

static id forced(NSString *key) {
    id value = SGRedesignForcedFlag(key);
    if (!value) value = SGFlagOverride(key);
    if (!value && SGFlag(SGKeySpotifyGlass, NO) && SGGlassOwnsFlag(key)) value = @YES;
    if (!value && SGAdBlockForcesFlagOff(key)) value = @NO;
    if (!value) value = SGLyricsForcedFlag(key);
    return value;
}

static BOOL boolFor(NSString *key, BOOL orig) {
    id value = forced(key);
    return value ? [value boolValue] : orig;
}

static long intFor(NSString *key, long lower, long upper, long orig) {
    id value = forced(key);
    return value ? MAX(lower, MIN(upper, (long)[value longLongValue])) : orig;
}

static id enumFor(NSString *key, id orig) {
    id value = forced(key);
    return [value isKindOfClass:NSString.class] ? value : orig;
}

%hook _TtC22RemoteConfigurationSDK25ConfigurationProviderImpl
- (BOOL)boolValueForId:(NSString *)key defaultValue:(BOOL)fallback {
    BOOL orig = %orig;
    return boolFor(key, orig);
}
- (long)intValueForId:(NSString *)key lower:(long)lower upper:(long)upper defaultValue:(long)fallback {
    long orig = %orig;
    return intFor(key, lower, upper, orig);
}
- (id)enumValueForId:(NSString *)key values:(NSArray *)values defaultValue:(id)fallback {
    id orig = %orig;
    return enumFor(key, orig);
}
%end

// The observable properties listed in Info.plist go through a second provider.
%hook _TtC22RemoteConfigurationSDK35ObservableConfigurationProviderImpl
- (BOOL)boolValueForId:(NSString *)key defaultValue:(BOOL)fallback {
    BOOL orig = %orig;
    return boolFor(key, orig);
}
- (long)intValueForId:(NSString *)key lower:(long)lower upper:(long)upper defaultValue:(long)fallback {
    long orig = %orig;
    return intFor(key, lower, upper, orig);
}
- (id)enumValueForId:(NSString *)key values:(NSArray *)values defaultValue:(id)fallback {
    id orig = %orig;
    return enumFor(key, orig);
}
%end

%hook SPTHubViewController
- (BOOL)prefersLiquidGlassNavigationBar {
    return SGFlag(SGKeySpotifyGlass, NO) ? YES : %orig;
}
%end

%ctor {
    %init;
    SGRequireClasses(@[
        @"_TtC22RemoteConfigurationSDK25ConfigurationProviderImpl",
        @"_TtC22RemoteConfigurationSDK35ObservableConfigurationProviderImpl",
        @"SPTHubViewController",
    ]);
}
