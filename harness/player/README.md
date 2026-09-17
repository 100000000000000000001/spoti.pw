# Player harness

Spotify's full screen player mocked under its own class names and accessibility identifiers
(from `trees/clean/player/01.txt`), so the redesign's lyrics state can be laid out, animated and
looked at on the Mac without the phone.

    THEOS=$HOME/theos ./build.sh
    xcrun simctl install booted build/PlayerHarness.app
    xcrun simctl launch booted com.vojta.playerharness
    xcrun simctl io booted screenshot shot.png

`build.sh` runs `logos.pl -c generator=internal` over `PlayerLyrics.x`, `PlayerArtwork.x`,
`PlayerFooter.x` and `PlayerScroll.x` and links them with the real `Core/`, `Redesigned/Kit/` and
`SGRKaraokeView`; `stubs.m` stands in for the hooks the harness does not compile (the Kit's bridges
and repaint, the rest of the player, the lyrics store, the haptics) and holds a song of ten timed
lines that plays on from launch.

The mock opens the lyrics two seconds after launch, closes them at six and opens them again at ten,
so a screenshot catches each state and a screen recording catches the move:

    xcrun simctl io booted recordVideo -f run.mp4      # ^C to stop
    ffmpeg -ss 2.9 -t 1.1 -i run.mp4 -vf "fps=10,scale=200:-1,tile=11x1" -frames:v 1 strip.png

It also lays every unit out once a second, which is what the transforms on Spotify's title row and
the narrowed marquee labels have to survive.

What it does not cover: the real element framework's autolayout, Spotify's own scrolled layout, the
player's open and close transition, and the artwork field behind the player (`PlayerField.x`).
