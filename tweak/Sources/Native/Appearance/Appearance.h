// Appearance: the AMOLED background (Amoled.x), the glass search field (SearchField.x), the
// accent colour in place of Spotify's green (Accent.x) and Repaint.x, which keeps what the other
// features stripped transparent when Spotify repaints it. The switches are off until asked for,
// as are the tab bar's and Spotify's own glass.
#import <UIKit/UIKit.h>

#define SGKeyAmoled @"spotifyglass.amoled"
#define SGKeySearchField @"spotifyglass.searchField"
#define SGKeyAccent @"spotifyglass.accent"   // 0xRRGGBB; unset or negative keeps Spotify's own green

UIColor *SGAccentColor(void);   // nil while Spotify's own green is kept
NSString *SGAccentLabel(void);  // "#RRGGBB", or the name of Spotify's own
void SGPickAccent(void);        // the system colour picker over the top of the app, stored on the way out

// Redesigned UI, the one switch of Appearance that sets others: the redesigned screens
// (Redesign/Kit/SGRedesign.h), Spotify's own glass and, with it, the tab bar, the search field, the now
// playing bar, the artwork background and the lyrics card. Each glass switch stays a switch of its own
// afterwards, on the page of the part it styles. SGRedesignedUIInfo is what its ⓘ reads out.
void SGSetRedesignedUI(BOOL on);
extern NSString *const SGRedesignedUIInfo;

@class SGModSection;
SGModSection *SGAppearanceSection(void);   // the Appearance card at the top of Mod Settings
