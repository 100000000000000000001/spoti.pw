// SPTEsperantoPlayer, the app's player, and the state it reports.
// The URIs are typed id: the runtime says only that they are objects, so a reader takes NSURL or NSString.
#import <Foundation/Foundation.h>

@interface SPTPlayerTrack : NSObject
@property (nonatomic, readonly) id URI;
@property (nonatomic, readonly) id artistURI;
@property (nonatomic, readonly) NSString *artistName;
@property (nonatomic, readonly) NSString *trackTitle;
// Every credited artist: artist_uri and artist_name, then artist_uri:1, artist_name:1 and on.
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *metadata;
@end

@interface SPTPlayerState : NSObject
@property (nonatomic, readonly) SPTPlayerTrack *track;
@end

@protocol SPTPlayer <NSObject>
@property (nonatomic, readonly) SPTPlayerState *state;
- (void)skipToNextTrack;
@end
