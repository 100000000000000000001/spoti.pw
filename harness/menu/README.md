# Menu harness

Spotify's context menu sheet (`ContextMenu_InternalImpl.ContextMenuViewController`) mocked under its
class name and presented from a now playing controller, so `PlayerMenu.x`'s hook adds Speed and pitch
the way it would on the phone. Speed and pitch themselves are stubs that log.

    THEOS=$HOME/theos ./build.sh
    xcrun simctl install booted build/MenuHarness.app
    xcrun simctl launch --console-pty booted com.vojta.menuharness [footer] [nospeed]

The menu opens at 1 s, the block at 3 s, both sliders move at 5 s and the block closes at 7 s.
`footer` gives the mock table a header of Spotify's, so the block goes to the footer; `nospeed` has
the player refuse speed.
