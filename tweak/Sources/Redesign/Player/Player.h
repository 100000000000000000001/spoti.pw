// The player redesign (screen key "player"): Spotify's full screen player kept, with its controller,
// units, controls and card list, and restyled from the Kit. Every control stays Spotify's own, so its
// action, state and accessibility do too; the redesign adds the artwork field behind it, glass behind
// the header buttons and the add button, bare glyphs for previous, play and next, a lyrics glyph in the
// footer, and collapses every card under the player except lyrics.
//
//     PlayerField.x      the switch's flags and rows, the field in the background plane, the cover it reads
//     PlayerArtwork.x    the cover's corners, shadow and paused shrink, the lyric preview under it hidden
//     PlayerHeader.x     glass behind the close and more buttons, and behind add
//     PlayerControls.x   previous, play and next as bare glyphs, monospaced times
//     PlayerFooter.x     share gone, lyrics, Connect and queue as one row of three glyphs
//     PlayerCards.x      the lyrics card kept on a content surface, every other card collapsed
//
// Every hook installs only while SGRedesignOn(@"player"); the legacy player hooks stand aside then.
// Threading: main thread only.
#import <UIKit/UIKit.h>

@class SGRArtworkField;

// Whether the lyrics card stays under the player; on until switched off. Off collapses it with the
// rest, and the lyrics glyph still opens the full screen page.
#define SGKeyRedesignPlayerLyricsCard @"spotifyglass.redesign.player.lyricsCard"

// The field behind the player, nil until the player has laid out once (PlayerField.x).
SGRArtworkField *SGRPlayerField(void);

// The lyrics card under the player while it is in a window, else nil (PlayerCards.x).
UIView *SGRPlayerLyricsCard(void);
// Called by PlayerCards.x when the card comes or goes, so the footer's lyrics glyph follows (PlayerFooter.x).
void SGRPlayerLyricsCardChanged(void);

// Alpha 0, no touches, hidden from accessibility, set again on every call: for Spotify's Swift views,
// which SGRSuppress cannot keep (PlayerControls.x).
void SGRPlayerVanish(UIView *view);
