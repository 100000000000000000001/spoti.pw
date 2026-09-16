// The chain: every source in the order the Lyrics page puts them in, asked one after another until
// there is nothing better left to learn.
//
// It keeps the best answer rather than the first, because the two halves of an answer come apart.
// A source can have the words of a song and no timing (Musixmatch, for a track it may only show as
// plain text), or the timing of every word and no text worth putting on Spotify's own page
// (NetEase). So the lines shown on the karaoke page and the lines handed to Spotify are chosen
// separately, and the walk stops once both are as good as they can get: every word timed, and text
// for the page.
#import "Core/SGCore.h"
#import "LyricsSources.h"
#import "Features/Karaoke/Karaoke.h"
#import "Headers/SPTPlayer.h"

static const NSTimeInterval kTimeout = 6;
static const NSUInteger kKeptTracks = 40;

// What the switches were called while Musixmatch was the only source; read once, to carry an
// existing install's settings over to the order.
static NSString *const kLegacyMusixmatch = @"spotifyglass.musixmatchLyrics";
static NSString *const kLegacyAllTracks = @"spotifyglass.musixmatchAllTracks";
static NSString *const kLegacyNetEase = @"spotifyglass.neteaseWordTiming";

@implementation SGLyricsResult
@end

@implementation SGLyricsQuery
@end

@implementation SGLyricsProvider
@end

#pragma mark - the requests the sources share

NSURL *SGLyricsURL(NSString *base, NSDictionary<NSString *, NSString *> *query) {
    NSURLComponents *url = [NSURLComponents componentsWithString:base];
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    [query enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        [items addObject:[NSURLQueryItem queryItemWithName:name value:value]];
    }];
    url.queryItems = items;
    return url.URL;
}

static void get(NSURL *url, NSDictionary<NSString *, NSString *> *headers, void (^done)(NSData *body)) {
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{ done(nil); });
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:kTimeout];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:name];
    }];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        if (error || status >= 400) SGLog(@"lyrics: %@ answered %ld, error %@", url.host, (long)status, error);
        dispatch_async(dispatch_get_main_queue(), ^{ done(status >= 400 ? nil : data); });
    }] resume];
}

void SGLyricsGetJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, void (^done)(id root)) {
    get(url, headers, ^(NSData *body) {
        done(body.length ? [NSJSONSerialization JSONObjectWithData:body options:0 error:nil] : nil);
    });
}

void SGLyricsGetText(NSURL *url, void (^done)(NSString *text)) {
    get(url, nil, ^(NSData *body) {
        done(body.length ? [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] : nil);
    });
}

// A pause this long between two lines gets a ♪, so Spotify's page does not hold the last one.
static const NSInteger kBreakMs = 3000;

void SGLyricsPageLines(NSArray<SGKaraokeLine *> *lines, NSArray<NSNumber *> **starts, NSArray<NSString *> **texts) {
    NSMutableArray<NSNumber *> *at = [NSMutableArray array];
    NSMutableArray<NSString *> *said = [NSMutableArray array];
    SGKaraokeLine *last = nil;
    for (SGKaraokeLine *line in lines) {
        if (last && line.start - last.end >= kBreakMs) {
            [at addObject:@(last.end)];
            [said addObject:@"♪"];
        }
        NSString *text = SGKaraokeLineText(line);
        // The backing vocals read on the same line on Spotify's own page, which has one row a line.
        if (line.backing) text = [text stringByAppendingFormat:@" %@", SGKaraokeLineText(line.backing)];
        [at addObject:@(line.start)];
        [said addObject:text];
        last = line;
    }
    if (last) {
        [at addObject:@(last.end)];
        [said addObject:@""];
    }
    *starts = at;
    *texts = said;
}

#pragma mark - which sources there are, and in what order

NSArray<SGLyricsProvider *> *SGLyricsAllProviders(void) {
    static NSArray<SGLyricsProvider *> *all;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLyricsProvider *(^make)(NSString *, NSString *, NSString *, SGLyricsAsk) =
        ^(NSString *key, NSString *name, NSString *detail, SGLyricsAsk ask) {
            SGLyricsProvider *provider = [SGLyricsProvider new];
            provider.key = key;
            provider.name = name;
            provider.detail = detail;
            provider.ask = ask;
            return provider;
        };
        all = @[
            make(@"binilyrics", @"BiniLyrics", @"Apple Music's own word timing, over a million tracks", SGBiniLyricsAsk),
            make(@"musixmatch", @"Musixmatch", @"The catalogue Spotify licenses; matched by track, never by name", SGMusixmatchAsk),
            make(@"unison", @"Unison", @"Written by hand for Better Lyrics: few tracks, the best of them", SGUnisonAsk),
            make(@"netease", @"NetEase", @"Word timing only, for what the others line time; swearing is starred out", SGNetEaseAsk),
            make(@"lrclib", @"LRCLIB", @"Open and keyless, timed by the line: the floor under the rest", SGLrcLibAsk),
        ];
    });
    return all;
}

SGLyricsProvider *SGLyricsProviderFor(NSString *key) {
    for (SGLyricsProvider *provider in SGLyricsAllProviders()) {
        if ([provider.key isEqualToString:key]) return provider;
    }
    return nil;
}

// An install from before the order existed keeps what it had: the sources it was using, in the only
// order there was. Nothing is switched on for it that it had not already asked for.
static NSArray<NSString *> *fromLegacyKeys(void) {
    if (!SGFlag(kLegacyMusixmatch, NO)) return @[];
    NSMutableArray<NSString *> *order = [NSMutableArray arrayWithObject:@"musixmatch"];
    if (SGFlag(kLegacyNetEase, NO)) [order addObject:@"netease"];
    return order;
}

NSArray<NSString *> *SGLyricsOrder(void) {
    id stored = [NSUserDefaults.standardUserDefaults arrayForKey:SGKeyLyricsProviders];
    NSArray *keys = [stored isKindOfClass:NSArray.class] ? stored : fromLegacyKeys();
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (id key in keys) {
        if ([key isKindOfClass:NSString.class] && SGLyricsProviderFor(key) && ![order containsObject:key]) [order addObject:key];
    }
    return order;
}

void SGLyricsSetOrder(NSArray<NSString *> *keys) {
    [NSUserDefaults.standardUserDefaults setObject:keys ?: @[] forKey:SGKeyLyricsProviders];
}

BOOL SGLyricsEnabled(void) {
    return SGLyricsOrder().count > 0;
}

#pragma mark - what is known about the track

// The player knows the track it is playing by name, which is what every source but Musixmatch
// searches by. A track that is not the one playing — a page opened for something else — starts with
// nothing, and the first source that matches by id fills the rest in.
static SGLyricsQuery *queryFor(NSString *trackID) {
    SGLyricsQuery *query = [SGLyricsQuery new];
    query.trackID = trackID;
    if (![trackID isEqualToString:SGKaraokePlayingTrack()]) return query;
    SPTPlayerTrack *track = [(id<SPTPlayer>)SGKaraokePlayer() state].track;
    query.title = track.trackTitle;
    query.artist = track.artistName;
    NSDictionary<NSString *, NSString *> *metadata = track.metadata;
    id album = metadata[@"album_title"];
    id length = metadata[@"duration"];
    if ([album isKindOfClass:NSString.class]) query.album = album;
    if ([length respondsToSelector:@selector(integerValue)]) query.seconds = [length integerValue] / 1000;
    return query;
}

static void learnFrom(SGLyricsQuery *query, SGLyricsResult *result) {
    if (!query.title.length && result.title.length) query.title = result.title;
    if (!query.artist.length && result.artist.length) query.artist = result.artist;
    if (!query.album.length && result.album.length) query.album = result.album;
    if (query.seconds <= 0 && result.seconds > 0) query.seconds = result.seconds;
}

#pragma mark - the walk

// Main queue only, except sg_missing and sg_credits.
static NSMutableDictionary<NSString *, id> *sg_kept;
static NSMutableDictionary<NSString *, NSMutableArray *> *sg_waiting;
static NSMutableSet<NSString *> *sg_missing;
static NSMutableDictionary<NSString *, NSString *> *sg_credits;

static void setUp(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sg_kept = [NSMutableDictionary dictionary];
        sg_waiting = [NSMutableDictionary dictionary];
        sg_missing = [NSMutableSet set];
        sg_credits = [NSMutableDictionary dictionary];
    });
}

// Whether the source's lines are better than what the walk already has: any lines beat none, and
// timing every word beats estimating them.
static BOOL betterLines(SGLyricsResult *merged, SGLyricsResult *fresh) {
    if (!fresh.karaokeLines.count) return NO;
    return !merged.karaokeLines.count || (fresh.wordTimed && !merged.wordTimed);
}

// The same for the text Spotify's own page shows: any text beats none, timed beats untimed.
static BOOL betterTexts(SGLyricsResult *merged, SGLyricsResult *fresh) {
    if (!fresh.texts.count) return NO;
    return !merged.texts.count || (fresh.synced && !merged.synced);
}

static void finish(NSString *trackID, SGLyricsResult *merged) {
    SGLyricsResult *lyrics = merged.karaokeLines.count || merged.texts.count ? merged : nil;
    if (sg_kept.count >= kKeptTracks) [sg_kept removeAllObjects];
    sg_kept[trackID] = lyrics ?: NSNull.null;
    if (!lyrics) {
        @synchronized (sg_missing) { [sg_missing addObject:trackID]; }
    }
    SGLog(@"lyrics: %@ ends with %@", trackID, !lyrics ? @"nothing"
          : [NSString stringWithFormat:@"%lu %@ lines from %@, %lu page lines",
             (unsigned long)lyrics.karaokeLines.count, lyrics.wordTimed ? @"word timed" : @"estimated",
             lyrics.provider, (unsigned long)lyrics.texts.count]);
    NSArray *waiting = sg_waiting[trackID];
    [sg_waiting removeObjectForKey:trackID];
    for (void (^done)(SGLyricsResult *) in waiting) done(lyrics);
}

static void askFrom(NSUInteger index, NSArray<NSString *> *order, SGLyricsQuery *query, SGLyricsResult *merged) {
    // Nothing left to gain: every word is timed and Spotify's page has its text.
    if (index >= order.count || (merged.wordTimed && merged.texts.count)) {
        finish(query.trackID, merged);
        return;
    }
    SGLyricsProvider *provider = SGLyricsProviderFor(order[index]);
    provider.ask(query, ^(SGLyricsResult *fresh) {
        learnFrom(query, fresh);
        if (fresh.instrumental) {
            SGLog(@"lyrics: %@ is instrumental, by %@", query.trackID, provider.key);
            finish(query.trackID, merged);
            return;
        }
        if (betterLines(merged, fresh)) {
            merged.karaokeLines = fresh.karaokeLines;
            merged.wordTimed = fresh.wordTimed;
            merged.provider = provider.name;
        }
        if (betterTexts(merged, fresh)) {
            merged.starts = fresh.starts;
            merged.texts = fresh.texts;
            merged.synced = fresh.synced;
            if (!merged.provider) merged.provider = provider.name;
        }
        askFrom(index + 1, order, query, merged);
    });
}

void SGLyricsFetch(NSString *trackID, void (^done)(SGLyricsResult *result)) {
    setUp();
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!trackID.length) {
            done(nil);
            return;
        }
        id kept = sg_kept[trackID];
        if (kept) {
            done(kept == NSNull.null ? nil : kept);
            return;
        }
        NSMutableArray *waiting = sg_waiting[trackID];
        if (waiting) {
            [waiting addObject:[done copy]];
            return;
        }
        sg_waiting[trackID] = [NSMutableArray arrayWithObject:[done copy]];
        askFrom(0, SGLyricsOrder(), queryFor(trackID), [SGLyricsResult new]);
    });
}

BOOL SGLyricsMayHave(NSString *trackID) {
    setUp();
    @synchronized (sg_missing) { return ![sg_missing containsObject:trackID]; }
}

NSString *SGLyricsCreditFor(NSString *trackID) {
    setUp();
    @synchronized (sg_credits) { return trackID ? sg_credits[trackID] : nil; }
}

void SGLyricsSetCredit(NSString *trackID, NSString *name) {
    setUp();
    if (!trackID.length) return;
    @synchronized (sg_credits) {
        if (sg_credits.count >= kKeptTracks) [sg_credits removeAllObjects];
        sg_credits[trackID] = name ?: @"Spotify";
    }
}

// Once, at launch: the keys Musixmatch owned alone become an order, so the Lyrics page opens on what
// the install was already doing rather than on nothing.
void SGLyricsMigrateLegacyKeys(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:SGKeyLyricsProviders]) return;
    NSArray<NSString *> *order = fromLegacyKeys();
    if (!order.count) return;
    SGLyricsSetOrder(order);
    SGSetEnabled(SGKeyLyricsAllTracks, SGFlag(kLegacyAllTracks, NO));
    SGLog(@"lyrics: carried the Musixmatch switches over as %@", [order componentsJoinedByString:@", "]);
}
