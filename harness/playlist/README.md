# Playlist harness

Spotify's playlist page mocked under its own class names and accessibility identifiers
(from `trees/clean/playlist/01.txt`), so `Redesigned/Playlist/` can be laid out and looked at
on the Mac without the phone.

    THEOS=$HOME/theos ./build.sh
    xcrun simctl install booted build/PlaylistHarness.app
    xcrun simctl launch booted com.vojta.playlistharness
    xcrun simctl io booted screenshot shot.png

`build.sh` runs `logos.pl -c generator=internal` over the three `.x` files and links them with the
real `Core/` and `Redesigned/Kit/` sources; `stubs.m` stands in for the two hook files the harness
does not compile (`SGRAccent.x`, `SGRRepaint.x`).

Two seconds after launch the mock puts Spotify's own frames back on the column and the action row
and asks both for a layout pass, which is what the redesign's `SGRObserveLayout` watch has to survive.

The page opens mid load, with the cover smaller and the block higher than they settle at, so the
picture has to grow to its final height and then hold it. Then it plays the three states the header is ever in, with the frames Spotify sets in each
(`trees/continuous/1.txt`, `2.txt` and `4.txt`): at rest at 4 s, collapsed at 8 s, pulled down past the
top at 12 s. Each logs where the hero landed in the window; collapsed it belongs off the top of the
screen, not pinned to it. At 16 s it fades Spotify's cover square and colour wash back in the way a
scroll does, with nothing laid out, and reports what the redesign's scroll pass made of them.

What it does not cover: the real element framework's autolayout, and the flags `PlaylistField.x` forces.

`liked` on the launch line (`xcrun simctl launch booted com.vojta.playlistharness liked`) builds Liked Songs
instead, from `trees/continuous/1.txt` (2026-09-18): no cover, a 238pt header, the count in a stack of its own,
the play button 80x48, and `LiquidGlass.gradientContainer`, which it fades in at 3 s as a scroll does.
