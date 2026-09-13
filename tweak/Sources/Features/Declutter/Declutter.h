// Declutter: cards under the player and sections of Home collapsed, player buttons hidden, one
// switch each (Declutter.x). The rows live on the Player, Lyrics and Home & Library pages. An unset switch is off.
#import <Foundation/Foundation.h>

#define SGHideShuffle @"spotifyglass.hide.shuffle"
#define SGHideRepeat @"spotifyglass.hide.repeat"
#define SGHideConnect @"spotifyglass.hide.connect"
#define SGHideShare @"spotifyglass.hide.share"
#define SGHideQueue @"spotifyglass.hide.queue"
#define SGHideAddTo @"spotifyglass.hide.addTo"
#define SGHideLyricsInline @"spotifyglass.hide.lyricsInline"
#define SGHideLyricsCard @"spotifyglass.hide.lyricsCard"
#define SGHideAboutArtist @"spotifyglass.hide.aboutArtist"
#define SGHideRelatedVideos @"spotifyglass.hide.relatedVideos"
#define SGHideSongDNA @"spotifyglass.hide.songDNA"
#define SGHideLiveEvents @"spotifyglass.hide.liveEvents"
#define SGHideExploreArtist @"spotifyglass.hide.exploreArtist"
#define SGHideCredits @"spotifyglass.hide.credits"
#define SGHideMerch @"spotifyglass.hide.merch"
#define SGHideRecommendations @"spotifyglass.hide.recommendations"
#define SGHideHomeShortcuts @"spotifyglass.hide.homeShortcuts"
#define SGHideHomePills @"spotifyglass.hide.homePills"
#define SGHideHomePromo @"spotifyglass.hide.homePromo"
#define SGHideHomePreviews @"spotifyglass.hide.homePreviews"
#define SGHideHomeDJ @"spotifyglass.hide.homeDJ"

// The welcome tour's one switch for the player: on hides every card under the player but the
// lyrics, off shows them again. The player's buttons are not its business. Only the tour reads
// it; the hooks read the keys above.
#define SGKeyPlayerLyricsOnly @"spotifyglass.hide.playerLyricsOnly"
void SGSetPlayerLyricsOnly(BOOL on);
