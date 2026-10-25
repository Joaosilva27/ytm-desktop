# YTM

A native macOS desktop app for YouTube Music. YTM wraps the real
[music.youtube.com](https://music.youtube.com) in AppKit and WebKit, so the
interface, recommendations, library, and playback are exactly the web app —
with native window behavior, media keys, and macOS integrations around it.

> Unofficial client. Not affiliated with, endorsed by, or sponsored by Google
> LLC. YouTube Music is a trademark of Google LLC.

![YTM showing the YouTube Music home page](docs/screenshots/home.png)

## Features

- **The real YouTube Music** — no reimplementation, no missing features. Sign
  in and your playlists, uploads, likes, and history are all there.
- **Persistent session** — cookies and site data live in the app's WebKit
  profile, so you stay signed in between launches.
- **Native window** — transparent full-size title bar with a real AppKit titlebar
  strip, so YouTube Music's layout is never stretched by CSS. The traffic lights
  and a visible **Mini Player** button sit above the page, and the app supports
  full screen, zoom, and back/forward gestures.
- **Now Playing integration** — Control Center, the macOS Now Playing panel,
  and hardware media keys control playback. The Mac is kept awake while music
  is playing.
- **Menu bar player** — play/pause, previous/next, like, artwork-free compact
  menu, and quick access to the window, mini player, and settings.
- **Mini player** — a floating always-on-top player with artwork, progress,
  and playback controls. Open it from the **Mini Player** button in the title
  bar, the View menu, the menu bar, or with ⌘⇧M.
- **Ad blocking** — a bundled content blocker removes known ad and tracking
  requests and hides promotional surfaces. A page script also strips ad
  metadata and fast-forwards in-player ads. Control it in
  **Settings → Privacy**.
- **Audio-only by default** — playback uses YouTube's audio-only stream for the
  current track, so no music video is displayed and the player shows the track
  artwork instead. When a track has a video, click the
  **Video** button in the title bar, use **View → Show Video**, or press ⌥⌘V
  to switch back to the video stream. The next track returns to audio-only
  automatically.
- **Dock menu** — playback controls plus quick access to the window and mini
  player, without bringing the window forward.
- **Native settings** — start page, menu bar player, keep-playing-on-close,
  always-on-top, ad blocking, external links, and launch at login.
- **Resilient** — loading and offline states, retry, and automatic reload if
  the WebKit content process is terminated.

| Mini player | Settings |
| --- | --- |
| ![Floating mini player](docs/screenshots/mini-player.png) | ![Native settings window](docs/screenshots/settings.png) |

## Requirements

- macOS 13 Ventura or later (Apple Silicon or Intel)
- Xcode Command Line Tools (`xcode-select --install`)

There are no third-party dependencies and no Xcode project to open.

## Build

```sh
git clone <this-repo> ytm-desktop
cd ytm-desktop
./Tools/build.sh
open dist/YTM.app
```

To build and copy the app into `/Applications` in one step:

```sh
./Tools/build.sh --install
```

The build compiles the Objective-C sources with `clang`, assembles
`dist/YTM.app`, copies the JavaScript resources, and ad-hoc signs the bundle.
The app is built locally, so it is not notarized.

## First run

1. Open YTM.
2. Click **Sign in** and complete Google's sign-in flow in the app window.
3. Play something. Click **Mini Player** in the title bar (or use
   **View → Show Mini Player**) to open the floating player.

Google sign-in is shown inside the app using a Safari-compatible user agent.
Credentials are entered directly on Google's pages; YTM never reads or stores
them. Authentication redirects never leave the app for a browser.

## How it works

- `Sources/WebController.m` owns the `WKWebView`, navigation policy, the
  JavaScript bridge, and in-app Google authentication. Internal links and
  sign-in redirects stay in the app; blank scripted popups are ignored so the
  page can never be replaced by an empty black document.
- `Resources/PlayerBridge.js` reads player state from the page and exposes
  play/pause, seek, previous/next, and like commands.
- `Sources/NowPlayingService.m` publishes metadata to MediaPlayer and handles
  remote commands and sleep prevention.
- `Sources/MainWindowController.m` builds the native 28pt titlebar strip and
  the **Mini Player** button, and keeps the page below the traffic lights in
  windowed mode and edge-to-edge in full screen.
- `Sources/StatusItemController.m` and `Sources/MiniPlayerController.m` provide
  the other native surfaces.
- `Sources/AdBlocker.m` compiles the bundled WebKit content-rule list and
  attaches it to the web view. `Resources/AdBlockRules.json` blocks known ad
  hosts and YouTube ad endpoints and hides promotional UI.
- `Resources/AdBlocker.js` prunes ad fields from player responses and
  fast-forwards any in-player ads that still appear.
- `Resources/AudioOnly.js` hooks the music app's player API to request
  YouTube's `audio_only=1` stream for every queue load, swaps in the track
  artwork while that stream plays, and exposes the per-track video toggle to
  the native titlebar.
- `Sources/LoginItemManager.m` manages a LaunchAgent in
  `~/Library/LaunchAgents` for launch at login.

The WebKit view uses a persistent data store at
`~/Library/WebKit/com.joaosilva.ytmdesktop` (plus the usual WebKit caches).

## Development

Build and run the snapshot harness used during development:

```sh
./Tools/snapshot.sh build/snapshot.png 12
```

The app also accepts hidden environment variables for local testing, including
`YTM_START_URL`,
`YTM_ACTION=mini|minibutton|settings|fullscreen|adblocktoggle|video`, `YTM_SNAPSHOT`,
`YTM_SNAPSHOT_MODE=window`, and `YTM_EPHEMERAL=1` (uses a non-persistent
WebKit profile). These are not user-facing settings.

Re-generate the app icon after editing `Tools/IconGen.m`:

```sh
./Tools/make-icon.sh
```

## Known limitations

- Playback, ads, and account behavior follow YouTube Music's web client and
  require an internet connection.
- Offline downloads and DRM-protected content are limited to what the web
  player itself supports.
- Launch at login writes a user LaunchAgent; moving the app after enabling the
  setting can leave a stale path behind. Toggle it off and on after moving the
  app.
- Some Google pages may ask you to verify the browser during sign-in. Complete
  the challenge in the app window.
- Ad blocking is best-effort: YouTube changes its ad delivery and player
  internals regularly. If playback misbehaves, turn off **Block ads and
  sponsored content** in Settings.
- Audio-only mode follows YouTube's own player availability. On the rare
  tracks where YouTube blocks audio-only playback, the player may keep using
  the video stream; the **Video** toggle remains available.

## License

MIT. See [LICENSE](LICENSE).
