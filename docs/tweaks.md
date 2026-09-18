# Working on the mod

## Layout

    tweak/                      the Theos project: Makefile, control, the bundle filter plist
    tweak/Sources/Core/         what every file builds on: logging, preferences, view-tree walking, glass panes, the
                                look this launch runs (SGUIMode.h), the forced-flag registry (SGFlagForce.h) and C
                                functions Spotify imports hooked by rebinding its import slots (SGRebind.h)
    tweak/Sources/Headers/      reverse-engineered Spotify classes, one header each, only the selectors used
    tweak/Sources/Settings/     the Mod Settings framework: SGPage (a page on Spotify's stack), SGModPage (sections
                                of rows), SGPageStyle (Spotify's list look), SGGlowSwitch
    tweak/Sources/Shared/       what works the same with either look, see Layers below
    tweak/Sources/Native/       tweaks on Spotify's own screens, running only while Redesigned UI is off
    tweak/Sources/Redesigned/   the redesign, running only while Redesigned UI is on
    tweak/Sources/App/          what brings the layers together: Mod Settings' root and composed pages, the Mod page,
                                backup and signing, the welcome tour
    tweak/Sources/Diagnostics/  screen dumps, the tree server and the main thread hang sampler of FLEX builds
    scripts/                    pipeline.sh (build + inject), install.sh (sign + install), record-trees.py,
                                record-session.py, dump-log.sh, extract-flags.py, publish.sh (release: version bump,
                                site release.json)
    trees/                      recorded view trees, one per screen; the input for every new hook. trees/clean/ holds
                                the numbered snapshots per screen of record-session.py, taken of Spotify as it came
    plist/                      Info.plist overrides merged into the app (turns UIDesignRequiresCompatibility off)
    vendor/                     AutoFLEX deb
    ipa/, out/                  decrypted Spotify IPA in, built IPAs out (both gitignored)

`tweak/Sources/Shared/Flags/SGFlagList.m` is generated from the IPA and gitignored, as are the
recorded trees: both are read out of Spotify's own binary and belong to whoever built them.

## Layers

The mod has two looks, picked by Redesigned UI in Appearance: Spotify's own screens with the mod's
tweaks on them, or the redesign, which starts from a clean sheet. What does not draw on Spotify's
screens works under both. So the sources are four layers, each a directory of features:

    Shared/       works the same with either look
    Native/       Spotify's own screens tweaked; every %ctor starts with `if (!SGNativeUI()) return;`
    Redesigned/   the redesign; every %ctor starts with `if (!SGRedesignedUI()) return;`
    App/          Mod Settings' root and the pages that combine the layers, the Mod page, the tour

The two looks never run together, so each hooks the same Spotify class in its own way, and a part of
the look is edited on its own side without touching the other: where both need the same thing, each
has its own copy (the tab bar's composition and its editor, the lyrics page's glass, the soft top edge,
AMOLED, the accent colour), under its own names (SG… native, SGR… redesign) and its own keys. The imports run
one way, Core <- Settings <- Shared <- Native | Redesigned <- App, and `scripts/check-layers.sh`, run
by tweak/Makefile before every build, fails on any other. A layer below that needs something from one
above takes it through a registry in Core (forced flags, SGFlagForce.h) or a function declared low and
defined high (SGOpenModSettings).

A feature is a directory in its layer holding everything about one area of the app:

    <Feature>.h            the keys of its switches, and the functions other files may call
    <Something>.x          the hooks, one file per screen or mechanism, each ending in its own %ctor
    <Feature>Settings.m    its Mod Settings page, or its sections for the page of the part it changes, built from
                           the rows in Settings/SGModPage.h; App/Pages.m puts them on the page
    <Model>.m              plain Objective-C the hooks and the page share, where there is any

Shared:

    AdBlock/      EeveeSpotify's ad blocking: the ad and upsell services silenced (AdServices.x), ad components out of the
                  Hub JSON (AdHubs.x) and the feeds (Feeds.m), Premium pop-ups dropped (AdPopups.x), and the responses
                  rewritten on the way in (AdNetwork.x, Premium.m over the protobuf walker in Protobuf.m), with crossfade
                  and automix switched on in the player core and crossfade's switch kept in step with its slider (Crossfade.x)
    Privacy/      telemetry blocking and its counters
    ArtistBlock/  tracks by blocked artists skipped as they start (ArtistSkip.x), the list and the Blocked artists page under Player
    Flags/        Spotify's remote-config flags: the provider hook, the generated table, the All flags page and the Labs page
    Gestures/     the double tap zones on the player: the grid, what each cell does, the recognizer (each look hooks it on)
    Lyrics/       the lyrics engine for the redesign's Apple Music style lyrics and the lock screen: lines read from
                  color-lyrics and the player's clock (KaraokeSource.x), words timed by estimate inside Spotify's line
                  times (KaraokeTiming.m), and the Lyrics page's parts
    LyricsSources/ the sources lyrics come from, asked in the order the Lyrics page puts them in and merged into the
                  best answer (LyricsSources.m, the list to drag in LyricsSourcesPage.m): Apple Music's TTML from
                  BiniLyrics.m and Unison.m, read by SGTTML.m, which is the only shape carrying a second voice and the
                  backing vocals; Musixmatch.m, matched by Spotify's track id with an anonymous token, word timed where
                  it has richsync; NetEase.m, word timing from yrc for what the others only line time; LrcLib.m, open and
                  keyless and timed by the line, the floor under the rest. color-lyrics is answered with whichever won
                  (LyricsHook.x): Spotify's own 200 gets our lines swapped in; a track Spotify's metadata says has none has
                  its request sent to a donor track that does, so the reply is a real 200 (a 404 answered as a 200 in the
                  delegate alone never showed the card on 9.1.78); a 404 for a track not seen yet is held until the chain
                  answers. The card list the server sends per track (scrollsita) carries a lyrics section only for tracks
                  Spotify has lyrics for, so one is added to any list without it: that is what makes the player ask for the
                  lyrics and show the card. has_lyrics is forced on for every track, the walk starts at the track change
                  for it and the next, and the player's card-loading timeout flag is forced to its 5 s maximum while a
                  source is on
    LockScreenLyrics/ the line being sung in the system's now playing
    Navigation/   the page transition fix (PageTransition.x) and opening a spotify: link (Links.x)
    Player/       the player's open and close announced (PlayerEvents.x), the lock screen widget's flags

Native:

    Appearance/   AMOLED (Amoled.x), the accent colour (Accent.x), the soft top edge (EdgeEffect.x), and Repaint.x, which
                  keeps what the native tweaks stripped transparent
    Navbar/       Spotify's tab bar composed (Navbar.x, NavbarLayout.m, hooked from TabBarHooks.x), the Navbar and Add a tab pages
    NowPlayingBar/ the device button hidden, the bar's flags
    Player/       the full screen player (Player.x), its cards and buttons hidden (PlayerDeclutter.x), the glass lyrics card
                  (LyricsCard.x), the gestures' hookup, the Queue & devices flags
    Lyrics/       the full screen lyrics page on glass (LyricsPage.x)
    Home/         the Home gradient, Home's sections and pills hidden (HomeDeclutter.x), the Home & Library page
    Playlist/     the playlist header and pills, hidden one switch each
    Album/, Artist/ their pages' parts hidden, and the cover or photo behind their headers

Redesigned:

    Kit/          what the redesign builds on (SGRKit.h lists it), the flags it forces (SGRedesign.h, SGRGlassDesign.x for
                  Spotify's own glass design), its repaint hook (SGRRepaint.x), soft top edge, AMOLED black (always on,
                  SGRAmoled.x) and its own accent colour (SGRAccent.x, stored apart from the native look's)
    Navbar/       the glass tab bar (TabBar.x) over its own composition (Navbar.x, NavbarLayout.m) and editor, the glass search field
    NowPlayingBar/ the glass now playing bar (NowPlayingBar.x), with Spotify's device button on it hidden on request
                  (BarConnect.x, its own key and its own Now playing page, apart from the native look's)
    Player/       the redesigned full screen player (Player.h lists its files)
    Lyrics/       the full screen lyrics page on glass with Apple Music style lyrics over it, always on (SGRKaraokeView,
                  which the player shows in itself too, Player/PlayerLyrics.x)
    Home/         Home decluttered to music on black (an allow list of its sections: shortcuts, the DJ without its heading and
                  transcript, the shelves of cards), a large title where the filter pills were with the avatar at the trailing
                  edge, the shelves' headings at the Music app's size, each shortcut tile's cover run across it blurred
                  (SGRPalette's extension), continuous corners on the covers, and in FLEX builds a meter of each scroll's
                  frames and the hooks' time (Home.h lists its files)
    Search/       the Browse page decluttered to its category cards (an allow list of the list's cells: the watch feed
                  carousels and promos collapse, and the cards move up by the spacing they leave), the header the way Home
                  has it without the camera, and each card as Liquid Glass tinted by its own colour, read off the Box's
                  shape layer (Search.h lists its files)
    Library/      Your Library the way Home and Search have their headers: a large title at the leading edge, the avatar
                  at the trailing edge with the search and create buttons before it, the filter chips and the header's
                  scrim gone and the header closed up by the band they leave, each row's artwork at the Kit's radius
                  with a circular one left round, a hairline between the rows, and the search inside the library on
                  glass capsules (Library.h lists its files)
    Playlist/     the playlist page (Liked Songs and one's own too, all three being the same page) the way the Music
                  app lays one out: the cover full bleed across the top dissolving into the page's field with no seam,
                  the title, the creator and the length centred under it, one row of glass controls (shuffle, a
                  prominent Play capsule taking its glyph and its word from Spotify's own button, add, more), the find
                  bar and the curation pills gone, and the track rows on the field with a hairline between them
                  (Playlist.h lists its files). Laid out on the Mac against harness/playlist/
    Album/        the album page laid out the same way, on the page the Creative Work Platform builds rather than the
                  playlist's, so it shares nothing with Playlist/ but the Kit: the cover full bleed dissolving into the
                  field, the title, the artist and the kind and date centred under it, and the same row of glass
                  controls -- play and shuffle float over the album page outside its header, so they are concealed
                  there and the row carries the Kit's stand-ins, which draw their glyph and fire them. Under the tracks
                  everything the server sends is dropped -- more by the artist, videos, concerts, merch, you might also
                  like, and whatever it adds next -- but the album's own line and its copyright (Album.h lists its
                  files). Laid out on the Mac against harness/album/
    Haptics/      Vibrations (Haptics.h lists its files): a tap of UIKit's feedback generators for the player's and the now
                  playing bar's controls, the scrubber's tenths and ends, cover swipes, gestures and the lyrics page's tap to
                  seek (ControlHaptics.x, SGRFeedback.m); and Music Haptics, Core Haptics playing along with the song:
                  Spotify's import of AudioOutputUnitStart is rebound so its RemoteIO output unit gets a render notify, the
                  samples go through a drum and bass analyzer on the render thread (SGRMusicAnalyzer.m, plain C), and a
                  thread of its own schedules the taps and the rumble for when the sound is heard (MusicHaptics.x). Both
                  switches apply at once; nothing plays while Spotify is not the active app

App:

    ModSettings.x  the root page and the rows that open it from Spotify's settings and the side drawer
    Pages.m        the Appearance card with Redesigned UI, the Player and Lyrics pages, which Navbar page opens
    About/         the update check, backup, the signing warning and the Mod page with the reset
    Onboarding/    the welcome page over Home on the first launch, with Redesigned UI, offered again from the Mod page

Every key a feature stores starts with `spotifyglass.`, whatever it holds: Reset all settings on
the Mod page removes by that prefix and has no list to keep up to date. It leaves `SGKeyStock` behind,
which makes every unset switch read off, so a reset is stock Spotify whatever switches exist.

A hook reads its switch when it runs (`SGEnabled`, `SGHidden`, `SGFlag` from Core/SGPrefs.h), so a
change shows after Spotify restarts; the tab editor on the Navbar page is the exception and applies as soon as the bar lays
out again, as are the Home gradient's colour, strength and height, but not the switch that turns it on, and the redesign's
Vibrations. The root page in `App/ModSettings.x` holds the Appearance card and links the page of each part of Spotify, and only the stored look's.

## Make targets

    make build      # out/Spotify-<version>-glass.ipa with FLEX in it
    make release    # the same without FLEX
    make install    # build without FLEX, sign with your certificate, install over USB
    make install FLEX=1   # the same with FLEX, which is what make trees reads through
    make trees      # record view trees screen by screen (FLEX build open on the phone, USB)
    make session    # clean trees, as many snapshots per screen as you like: Enter saves, n goes to the next screen
                    # (SCREENS="playlist artist" for some); every snapshot says whether the mod was at stock
    make log        # stream [spotifyglass] log lines from the phone
    make flags      # regenerate the flag table from the IPA

## Mod Settings

Mod Settings, opened by holding Home on the tab bar or from the first row of the side drawer and the
last row of Spotify's Settings, sorts every
setting by the part of Spotify it changes, so a part's glass, its hide switches and its flags sit on
one page, the mod's own rows first and Spotify's flags below them or on a sub page named after what
they change. It opens on the Appearance card: Redesigned UI, then the stored look's accent colour, and in the native
look AMOLED (the redesign is always black); Spotify's green is offered from the colour row once a colour
is set. Redesigned UI is the one switch between the two looks (see Layers): it glows
(Settings/SGGlowSwitch), its ⓘ says what it changes, and flipping it offers to restart Spotify.
The pages show only what the stored look has: a page opened after flipping the switch already shows
what the restart will bring. Then a card of parts. Navbar: the tab editor of the stored look, each with
its own list of tabs. Player: Gestures, Lyrics (the ordered list of lyrics sources, lyrics for every track,
naming the source in the redesign, the lock screen, and glass lyrics in the native look), Blocked artists (with the count on the row) and Lock screen widget, which work with either look;
in the native look also Now playing bar (its device button and its flags), Queue & devices, and
Spotify's own player screen (artwork background, glass header buttons, Disable Canvas and the sheet,
header, slider and sticky header flags, the cards under the player and the lyrics preview and player
buttons to hide); in the redesign instead Now playing (its device button), Vibrations, Controls (on until switched off) and Music Haptics
(off until switched on, with an ⓘ saying it follows the sound this iPhone plays while Spotify is open), both
applying straight away. Home & Library, in the native look only:
the Gradient page (the wash behind the top of Home in one of eight colours, at three strengths and
four heights) and the Home flags, the parts of Home to hide including the DJ button and badge, the
playlist header, buttons and pills to hide, and the Library flags. Then Premium, ads & privacy
(EeveeSpotify's Hide ads and Hide upsells, hiding the video carousel and social proof in Search, and
an Ad and upsell flags page under them, every switch there forcing a flag Spotify ships on to off;
Spoof Premium; Block telemetry; then what the ad
blocking and the telemetry blocking have stopped) and Labs (features Spotify built and did not ship,
AI Chat (Martini) first). Last, All flags, Spotify's remote-config flags with a search field and an
Auto / Off / On control per flag (a text field for the number and text ones), and Mod: the update
check, the build and Spotify's version, the site and the repo, the welcome tour again and Reset all
settings. A flag switch on a page forces that one flag and off leaves Spotify's own value, so the All
flags page is where a flag goes back to Auto. Spotify ships its newer design behind several flags at
once, and the redesign is built on it (the glass navigation bar, the new player slider, the sheet style
player, the queue and Connect sheets, the redesigned player header, the sleep timer's options sheet):
while Redesigned UI is on each is forced, over an override too, and their rows elsewhere show what is
forced and take no touch. `Redesigned/Kit/SGRGlassDesign.x` holds the list; what else forces a flag
registers in `Core/SGFlagForce.h`. A change shows after Spotify restarts.

The tab editor on the Navbar page is the exception and applies as soon as the bar lays out again. It lists the tabs in the order
the bar shows them: drag to reorder, tap to hide or show, and Add a tab puts a page of Spotify's or
any `spotify:` link on the bar with one of Encore's own glyphs. Spotify's own tabs are kept by the
name under their icon, so they can be hidden but never removed, and switching the app's language
starts the order over. A tab of the mod's own opens its link through Spotify's link dispatcher, so it
never lights up as the tab you are on. Hide labels, on the same page, leaves the glass bar with its
icons alone and applies straight away too.

## Adding a feature

1. `make trees`, record the screen, read `trees/<screen>.txt` for the classes and frames.
2. Decide the layer (see Layers), then make `tweak/Sources/<Layer>/<Feature>/` with `<Feature>.h` declaring the switch key
   (`#define SGKey<Feature> @"spotifyglass.<feature>"`) and `UIViewController *SG<Feature>SettingsPage(void)`.
3. Add the hooks in `<Screen>.x`: `#import "Core/SGCore.h"` and the feature header, guard on the
   switch, use `SGGlassFor`/`SGGlassAt` + `SGShapeGlass` for glass and `SGStripBackgrounds` to clear
   Spotify's paint, and end with `%ctor { %init; SGRequireClasses(@[...]); }`, gated first on the layer's look
   (`SGNativeUI()` or `SGRedesignedUI()`) in Native/ and Redesigned/.
4. Add `<Feature>Settings.m` returning an `SGModPage` of `SGSection`s of `SGSwitchRow`/`SGHideRow`/
   `SGFlagRow` (Settings/SGModPage.h), and put it on the page of the part of Spotify it changes in `App/Pages.m`
   or `App/ModSettings.x`.
5. `make install`. Log lines are prefixed `[spotifyglass]`. A FLEX build serves the visible screen's
   tree on the phone's port 8085, which `make trees` reaches over USB through iproxy.

A class Spotify has renamed shows up in the log as `class X not found, its hooks are inactive`;
declare the classes a feature needs in `Headers/` only when a hook calls into them by type.
