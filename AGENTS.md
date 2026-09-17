# spoti.pw

A Theos tweak (Objective-C + Logos) injected into the decrypted Spotify iOS app. The full guide is
`docs/tweaks.md`; read it before changing code.

## Two looks, never both

**Redesigned UI** (Mod Settings → Appearance) picks one of two looks, read once at launch:

- **Native**: Spotify's own screens with the mod's tweaks on them (hide switches, glass header buttons,
  Home gradient, AMOLED switch, accent colour...).
- **Redesigned**: the mod's own Liquid Glass look, from a clean sheet. It includes the glass tab bar,
  search field and now playing bar, the redesigned player and lyrics page with Apple Music style lyrics
  always on, a decluttered Home, Search's categories on tinted glass, a Library with one large title and no
  filter pills, black throughout, and its own accent colour. No native tweak runs.

Anything that doesn't draw on Spotify's screens works the same under both: ads, privacy, lyrics
sources, gestures, blocked artists, flags.

## Where code goes (`tweak/Sources/`)

| Layer | What | Gate at the top of every `%ctor` |
|---|---|---|
| `Shared/` | behaviour and data, either look | none |
| `Native/` | Spotify's screens tweaked | `if (!SGNativeUI()) return;` |
| `Redesigned/` | the redesign (`Kit/` + parts) | `if (!SGRedesignedUI()) return;` |
| `App/` | Mod Settings root and combined pages, Mod page, tour | none |
| `Core/`, `Settings/`, `Headers/`, `Diagnostics/` | infrastructure | none |

Rules:

- Imports run one way: `Core <- Settings <- Shared <- Native | Redesigned <- App`. Native and
  Redesigned never import each other. `scripts/check-layers.sh` runs before every build and fails on a
  violation. Don't work around it.
- Change one look without touching the other. When both need the same thing, each side keeps its own
  copy under its own names (`SG…` native, `SGR…` redesign) and its own keys. Examples are the tab bar
  composition and editor, AMOLED and the accent colour. Don't merge copies back into
  a shared file.
- A lower layer that needs something from a higher one gets it through a registry in `Core`
  (forced flags: `Core/SGFlagForce.h`) or a function declared low and defined high.
- Settings: each layer builds its own rows and sections. `App/Pages.m` and `App/ModSettings.x`
  decide what to show from `SGRedesignedUIStored()`, so native-only pages disappear in the redesign.
- Keys start with `spotifyglass.` (redesign-only ones with `spotifyglass.redesign.`). Switches are
  read at launch, so a change needs a restart.

## Working on it

- Build: `make install` (signs and pushes to the phone), `make release` (IPA only). Tweak only:
  `env -u MAKELEVEL gmake -C tweak clean package`.
- Look at Spotify's views through recorded trees (`make session` records clean ones into
  `trees/clean/`) before hooking anything. Prove every class and selector against the tree or the binary.
- Device log: `make log` (`[spotifyglass]` lines).
- Known traps: anything pushed onto Spotify's nav stack must conform to `SPTPageController`
  (`Settings/SGPage.m`). Setting `hidden` on views inside Spotify's `OverflowStackView` or its Encore
  stacks crashes, so use alpha. A `CADisplayLink` capped at 60 Hz drags the player's 120 Hz
  transitions down with it.
