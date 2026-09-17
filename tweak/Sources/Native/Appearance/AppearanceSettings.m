#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Appearance.h"
#import "Native/Navbar/Navbar.h"
#import "Shared/Flags/Flags.h"
#import "Native/Player/NowPlaying.h"
#import "Redesigned/Kit/SGRedesign.h"

NSString *const SGRedesignedUIInfo = @"Replaces Spotify's own screens with the mod's redesign, built in Liquid Glass: for now the full screen player with the lyrics under it, and every screen redesigned later joins it here. It also turns on Spotify's own glass bars, slider and sheets, and the mod's glass tab bar, search field and now playing bar.\n\nWhile it is on, the switches that change Spotify's own version of a redesigned screen are put away on that screen's page, since the screen is no longer Spotify's. Off, Spotify looks the way it does with the switches you set.\n\nChanges apply after you restart Spotify.";

void SGSetRedesignedUI(BOOL on) {
    for (NSString *key in @[SGKeyRedesign, SGKeySpotifyGlass, SGKeyTabBar, SGKeySearchField, SGKeyNowPlayingBar, SGKeyPlayer, SGKeyPlayerBackdrop, SGKeyLyricsCard]) {
        SGSetEnabled(key, on);
    }
}

// Going back to Spotify's green is offered only once a colour of the mod's is set, so a stray tap
// cannot wipe it.
static void chooseAccent(void) {
    if (!SGAccentColor()) {
        SGPickAccent();
        return;
    }
    UIViewController *top = SGTopController();
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Accent colour" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Pick a colour" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { SGPickAccent(); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Spotify's green" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { SGSetInt(SGKeyAccent, -1); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = top.view;
    sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 0, 0);
    sheet.popoverPresentationController.permittedArrowDirections = 0;
    [top presentViewController:sheet animated:YES completion:nil];
}

SGModSection *SGAppearanceSection(void) {
    SGModRow *redesign = SGOptionRow(@"Redesigned UI", @"The mod's own screens in Liquid Glass, and every glass switch with them", SGKeyRedesign);
    redesign.glows = YES;
    redesign.info = SGRedesignedUIInfo;
    redesign.changed = ^(BOOL on) { SGSetRedesignedUI(on); };
    return SGNotedSection(@"Appearance", @[
        SGWithSymbol(redesign, @"sparkles"),
        SGWithSymbol(SGOptionRow(@"AMOLED background", nil, SGKeyAmoled), @"moon"),
        SGWithSymbol(SGStatActionRow(@"Accent colour", nil, ^NSString *{ return SGAccentLabel(); }, ^{ chooseAccent(); }), @"paintpalette"),
    ], @"Redesigned UI turns every glass switch of the mod's on or off with it. Changes apply after you restart Spotify.");
}
