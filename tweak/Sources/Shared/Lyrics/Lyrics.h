// The lyrics engine: timed lines and the player's clock, for the redesign's Apple Music style lyrics
// (Redesigned/Lyrics/SGRKaraokeView.h) and the lock screen (Shared/LockScreenLyrics). Spotify only
// times whole lines, so the words inside a line are timed by an estimate (KaraokeTiming.m), unless a
// source of the mod's times them. The lines are read from the color-lyrics response as it arrives, or
// handed over by Shared/LyricsSources, and the position from the player's state (KaraokeSource.x).
#import <UIKit/UIKit.h>

@class SGModRow, SGModSection;
// LyricsSettings.m: the Lyrics page's parts (App/Pages.m puts the page together): where lyrics come
// from, naming the source (read by the redesign's lyrics view only), the lock screen, and which
// language a line's translation is taken in, of those the lyrics come with (the redesign's lyrics
// being where translations show).
SGModSection *SGLyricsSourcesSection(BOOL namingSource);
SGModRow *SGLockScreenLyricsRow(void);
SGModRow *SGLyricsTranslationLanguageRow(void);

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
// How the line sounds, written in the Latin alphabet (Apple Music's pronunciation): its words sung
// at the times of the line's own, each starting with the word it spells, and the backing's under the
// backing. nil where the source has none, or where it reads the same as the line.
@property (nonatomic, strong) SGKaraokeLine *pronunciation;
// The line in another language, the backing's words with it; nil where the source has none.
@property (nonatomic, copy) NSString *translation;
@end

// The line as one string, a space between the words that are not joined.
NSString *SGKaraokeLineText(SGKaraokeLine *line);
// When the singing of a line is over: its own end, or its backing's when that runs on past it.
NSInteger SGKaraokeSungEnd(SGKaraokeLine *line);
// The one line a place with room for one names as the one being sung at `ms`. Two voices can sing
// over each other, and a line another voice comes in over keeps its place until it is sung out, so
// this is the earliest line still being sung; between lines, the last one begun; -1 before the first.
// The lock screen and the Live Activity show this one.
NSInteger SGKaraokeLeadLine(NSArray<SGKaraokeLine *> *lines, NSInteger ms);
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
// The Authorization header Spotify's own requests carry, "Bearer ..." and the account's own token;
// nil until one has gone out. Only for a source that answers no one who cannot show they are a
// signed-in Spotify client, and only with the mod's user having switched that source on.
NSString *SGKaraokeSpotifyAuthorization(void);
NSString *SGKaraokePlayingTrack(void);   // the base62 id, nil before the player reported
NSInteger SGKaraokePositionMs(void);     // negative when unknown
void SGKaraokeSeek(NSInteger ms);
id SGKaraokePlayer(void);                // SPTEsperantoPlayer, nil before the app asked it for its state
// A track the player has reported, by its base62 id; nil for one it has not played this session.
@class SPTPlayerTrack;
SPTPlayerTrack *SGKaraokeTrackFor(NSString *trackID);
// Keeps a track seen elsewhere, so a source can name it before the player has reported it.
void SGKaraokeRememberTrack(SPTPlayerTrack *track);
