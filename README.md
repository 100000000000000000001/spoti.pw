<p align="center">
  <img src="docs/icon.png" width="96" alt="">
</p>

<h1 align="center">spoti.pw</h1>

<p align="center">Spotify, in glass.</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white" alt="iOS">
  <img src="https://img.shields.io/badge/Spotify-1ED760?style=for-the-badge&logo=spotify&logoColor=white" alt="Spotify">
  <img src="https://img.shields.io/badge/Objective--C-3A95E3?style=for-the-badge&logo=apple&logoColor=white" alt="Objective-C">
  <img src="https://img.shields.io/badge/GitHub_Actions-2671E5?style=for-the-badge&logo=githubactions&logoColor=white" alt="GitHub Actions">
  <img src="https://img.shields.io/badge/License-GPL_v3-blue?style=for-the-badge" alt="GPL-3.0">
</p>

<p align="center">
  <a href="https://spoti.pw">spoti.pw</a> ·
  <a href="#get-it">Get it</a> ·
  <a href="#build-it-yourself">Build it yourself</a> ·
  <a href="docs/tweaks.md">Hack on it</a>
</p>

<p align="center">
  <img src="docs/screenshots/now-playing.webp" width="19%" alt="Full screen player">
  <img src="docs/screenshots/queue.webp" width="19%" alt="Queue as a bottom sheet">
  <img src="docs/screenshots/home.webp" width="19%" alt="Home with the gradient">
  <img src="docs/screenshots/navbar.webp" width="19%" alt="Navbar editor">
  <img src="docs/screenshots/settings.webp" width="19%" alt="Mod Settings">
</p>

A Theos tweak that rebuilds Spotify for iOS in Liquid Glass. One dylib injected into a decrypted
IPA, signed with your own certificate, no jailbreak. Every piece has a switch in Settings → Mod
Settings.

What is in, and what is next.

- [x] Liquid Glass, every flag of it at once
- [x] AMOLED black, Home gradient
- [x] Ad blocking
- [x] Spoof Premium
- [x] Tracker blocking
- [x] Custom tab bar
- [x] Double tap zones on the player
- [x] Like and dislike on the lock screen
- [x] Hide anything
- [x] Every flag Spotify ships
- [ ] Custom lyrics
- [ ] Block an artist
- [ ] Radio stations from a stream URL
- [ ] Alternate app icons
- [ ] Open on the tab you choose
- [ ] Long press and swipe gestures

## Get it

No IPA is distributed, here or on [spoti.pw](https://spoti.pw). Fork the repo and
[build it yourself](#build-it-yourself) from your own decrypted Spotify IPA; the GitHub workflow
needs no Mac. The Mod page tells you when a newer version is out.

The app keeps Spotify's bundle id, so it installs over the real Spotify. Sign it under a mismatched
App ID and it still installs, but the lock screen card opens nothing.

### Signing it yourself

In Feather, set **Identifier** to the App ID in its certificates tab and leave **PPQ protection**
off. AltStore, SideStore and Sideloadly work this out themselves.

A build the lock screen cannot open says so on first launch and names the bundle id to sign under.

## Build it yourself

Bring a decrypted Spotify IPA. The result is an unsigned `Spotify-<version>-glass.ipa`, to sign with
SideStore, Feather or any certificate signer.

### On GitHub, no Mac needed

Fork the repo, enable Actions, run the **Build IPA from your own Spotify IPA** workflow. It takes a
direct link to your decrypted `.ipa` and hands the built IPA back as a workflow artifact. The link is
masked in the log and the result stays in your fork.

### On a Mac

Theos in `~/theos` and an iPhoneOS 26 or newer SDK, from Xcode (`xcode-select` it) or in `~/theos/sdks`, plus:

    brew install make ldid dpkg zsign ideviceinstaller libimobiledevice
    uv tool install "cyan @ git+https://github.com/asdfzxcvbn/pyzule-rw"

Put the decrypted `.ipa` in `ipa/`, then:

    make release    # out/Spotify-<version>-glass.ipa, ready to sign
    make install    # the same, signed with your certificate and pushed to the iPhone over USB

`make install` reads `SIGN_P12`, `SIGN_PROFILE` and `SIGN_P12_PASSWORD` from `.signing.env`; copy
`.signing.env.example` and fill it in. It signs under your profile's App ID, which is what keeps the
lock screen player working.

The first build spends a minute reading Spotify's flags out of your IPA, so the flag list matches the
Spotify you built from. `make flags` regenerates it.

## Star history

<a href="https://star-history.com/#skopevoj/spoti.pw&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=skopevoj/spoti.pw&type=Date&theme=dark">
    <img src="https://api.star-history.com/svg?repos=skopevoj/spoti.pw&type=Date" alt="Star history chart">
  </picture>
</a>

## Credits

[cyan](https://github.com/asdfzxcvbn/pyzule-rw) injects, [Theos](https://theos.dev) builds, and
[FLEX](https://github.com/FLEXTool/FLEX), as hopeless's AutoFLEX build in `vendor/`, is the inspector
the view trees are read through. The ad blocking and the Premium state are ported from
[EeveeSpotify Reincarnated](https://github.com/SideloadLabs/EeveeSpotifyReincarnated).

GPL-3.0. Not affiliated with Spotify.
