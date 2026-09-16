// Apple Music style lyrics on the full screen lyrics page: the line being sung lights up word by
// word, the rest dim and blur with distance. Spotify only times whole lines, so the words inside a
// line are timed by an estimate (KaraokeTiming.m), unless a source of the mod's times them. The
// lines are read from the color-lyrics response as it arrives, or handed over by
// Features/LyricsSources, and the position from the player's state (KaraokeSource.x); a track
// without synced lyrics keeps Spotify's own page.
#import <UIKit/UIKit.h>

#define SGKeyKaraokeLyrics @"spotifyglass.karaokeLyrics"

// Which edge a line is laid against. Apple Music puts a duet's second voice against the far one, so
// the two sides of the song read apart; a track sung by one voice stays leading throughout.
typedef NS_ENUM(NSUInteger, SGKaraokeAlign) {
    SGKaraokeAlignLeading = 0,
    SGKaraokeAlignTrailing,
};

// Times in milliseconds from the start of the track.
@interface SGKaraokeWord : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic) NSInteger start, end;
// Set when nothing separates the word from the one before it, as between Japanese, Chinese or Korean
// syllables: the line lays it flush instead of leaving a space for a word break that is not there.
@property (nonatomic) BOOL joined;
@end

@interface SGKaraokeLine : NSObject
@property (nonatomic, copy) NSArray<SGKaraokeWord *> *words;
@property (nonatomic) NSInteger start, end;
// The voice singing the line, named as the source names it ("v1", "v2"), nil when it names none.
// SGKaraokeAlignVoices turns these into alignments; nothing else reads it.
@property (nonatomic, copy) NSString *voice;
@property (nonatomic) SGKaraokeAlign align;
// The (oh, aye) sung under the line, smaller and dimmer, nil for nearly every line. Its words are
// timed like any other and it is lit by the same sweep, a beat behind the line it hangs off.
@property (nonatomic, strong) SGKaraokeLine *backing;
@end

// The line as one string, a space between the words that are not joined.
NSString *SGKaraokeLineText(SGKaraokeLine *line);
// Whether the text is written in a script that does not space its words, so the pieces of a line
// are words in their own right rather than halves of one.
BOOL SGKaraokeUnspacedScript(NSString *text);
// Gives every line the alignment its voice earns: the voice heard first leads, the next one to be
// named trails, and any after that lead again. A track naming one voice or none is left alone.
void SGKaraokeAlignVoices(NSArray<SGKaraokeLine *> *lines);

// A color-lyrics body, protobuf or JSON, as timed lines; nil unless Spotify synced it by line.
NSArray<SGKaraokeLine *> *SGKaraokeLinesFromBody(NSData *body);
// Lines timed only by their starts, the words inside them estimated; a ♪ or empty text is a break.
NSArray<SGKaraokeLine *> *SGKaraokeEstimatedLines(NSArray<NSNumber *> *starts, NSArray<NSString *> *texts);

NSArray<SGKaraokeLine *> *SGKaraokeLinesForTrack(NSString *trackID);   // nil until the lyrics came
void SGKaraokeKeepLines(NSString *trackID, NSArray<SGKaraokeLine *> *lines);
// Asks spclient for a track's lyrics once, with the headers of Spotify's own requests, for when no
// page of Spotify's has asked for them, e.g. with the app in the background.
void SGKaraokeRequestLyrics(NSString *trackID);
NSString *SGKaraokePlayingTrack(void);   // the base62 id, nil before the player reported
NSInteger SGKaraokePositionMs(void);     // negative when unknown
void SGKaraokeSeek(NSInteger ms);
id SGKaraokePlayer(void);                // SPTEsperantoPlayer, nil before the app asked it for its state

@interface SGKaraokeView : UIView
// Hides Spotify's own lyrics next to this view while it has lyrics to show, and brings them back when not.
- (void)syncSiblings;
@end
