// The controls a redesigned page puts in the row under its hero, where the Music app has them: the Play
// capsule it draws instead of a disc, and a round button standing in for one of Spotify's own where that
// one cannot be brought into the row.
//
// Neither is a control of its own making. Each takes what it shows from a button of Spotify's -- the glyph
// it draws, the word beside it in the app's own language, whether it reads play or pause -- and a tap on it
// fires that button, so the action, the state and the accessibility stay Spotify's and only the drawing is
// the redesign's. A page that can move Spotify's button into its row moves it and needs neither.
//
// Ownership: whoever adds them; each keeps a weak reference to Spotify's control.
// Threading: main thread only.
#import <UIKit/UIKit.h>

// A capsule the height of SGRActionHeight with a glyph and a word in it, on prominent glass: the one
// control of an action row that leads. `sgr_width` is the width the word it is showing asks for.
@interface SGRPlayCapsule : UIControl
// Spotify's play button, the one the capsule reads and fires. Set by -feedFrom:.
@property (nonatomic, weak, readonly) UIView *source;
// A solid capsule of this colour instead of the prominent glass, the Music app's white Play (the playlist).
// nil, the default, is the glass. Set before the capsule is first laid out.
@property (nonatomic, copy) UIColor *fillColor;
// The glyph's and the word's colour; nil is the accent.
@property (nonatomic, copy) UIColor *contentColor;
// Takes the glyph, the word and the language from `source`, and follows the glyph as Spotify swaps it
// (play becoming pause) without the header laying out again. Cheap to call again on every pass.
- (void)feedFrom:(UIView *)source;
- (CGFloat)sgr_width;
@end

// A round glass button SGRActionHeight across showing the glyph of one of Spotify's round buttons and
// firing it, for a control the row cannot reach: the album page's shuffle floats over the page rather
// than scrolling with its header, so it is left where it is, concealed, and this stands in for it.
@interface SGRMirrorButton : UIControl
@property (nonatomic, weak, readonly) UIView *source;
// Drawn, in white, when Spotify's button has no image view to copy (a glyph it draws itself).
@property (nonatomic, strong) UIImage *fallbackGlyph;
// Takes the glyph, its colour and the label from `source`, and follows the glyph as Spotify swaps it
// (shuffle turning on). Cheap to call again on every pass.
- (void)feedFrom:(UIView *)source;
@end
