Native macOS desktop app for YouTube Music — the real music.youtube.com in an
AppKit + WebKit window, with media keys, a menu bar player, a floating mini
player, audio-only playback and ad blocking.

[![Download for macOS](https://raw.githubusercontent.com/Joaosilva27/ytm-desktop/__TAG__/docs/screenshots/download-button.png)](https://github.com/Joaosilva27/ytm-desktop/releases/download/__TAG__/YouTube-Music-__VERSION__.dmg)

**[Download YouTube-Music-__VERSION__.dmg](https://github.com/Joaosilva27/ytm-desktop/releases/download/__TAG__/YouTube-Music-__VERSION__.dmg)**
— universal build for Apple silicon and Intel, macOS 13 or later.

## Install

**1. Open the disk image and drag the app into Applications.**

![Dragging the app into Applications](https://raw.githubusercontent.com/Joaosilva27/ytm-desktop/__TAG__/docs/screenshots/install-drag.png)

**2. Open YouTube Music from your Applications folder.**

The first launch is blocked: the app is built outside the App Store and is not
notarized by Apple, so macOS cannot verify it.

**3. Allow it once in System Settings → Privacy & Security.**

![Open Anyway in Privacy & Security](https://raw.githubusercontent.com/Joaosilva27/ytm-desktop/__TAG__/docs/screenshots/install-open.png)

Click **Open Anyway**, confirm with your password, then click **Open Anyway**
again in the final dialog. macOS remembers the choice, so this happens only
once.

Prefer the terminal? This does the same thing:

```sh
xattr -dr com.apple.quarantine "/Applications/YouTube Music.app"
```

Then sign in with Google inside the app and press play.

## What's new

__CHANGES__

## Requirements

- macOS 13 Ventura or later, Apple silicon or Intel
- An internet connection — playback follows YouTube Music's web player

## Verify the download

The disk image is checksummed; the release also carries a `.sha256` file:

```sh
shasum -a 256 -c "YouTube-Music-__VERSION__.dmg.sha256"
```

## Notes

- The app is ad-hoc signed and not notarized. Gatekeeper therefore asks for
  confirmation on the first launch (step 3 above). Nothing is sent anywhere.
- Google sign-in happens inside the app window; the app never sees your
  password.
- Uninstall by quitting the app and dragging it from Applications to the Bin.
  Your session lives in `~/Library/WebKit/com.joaosilva.ytmdesktop`.

Unofficial client. Not affiliated with, endorsed by, or sponsored by Google
LLC. YouTube Music is a trademark of Google LLC.

See the [README](https://github.com/Joaosilva27/ytm-desktop#readme) for the full
feature list, build instructions and known limitations.
